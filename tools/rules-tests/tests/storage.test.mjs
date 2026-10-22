import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteObject, getBytes, listAll, ref, uploadBytes } from 'firebase/storage';

const rules = readFileSync(new URL('../../../storage.rules', import.meta.url), 'utf8');
const MAX = 5 * 1024 * 1024;

describe('storage.rules', () => {
  let env;

  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-inner-stars',
      storage: { rules, host: '127.0.0.1', port: 9199 },
    });
  });

  after(() => env.cleanup());
  beforeEach(() => env.clearStorage());

  const alice = () => env.authenticatedContext('alice').storage();
  const bob = () => env.authenticatedContext('bob').storage();
  const nobody = () => env.unauthenticatedContext().storage();

  const bytes = (size = 16) => new Uint8Array(size).fill(7);
  const jpeg = { contentType: 'image/jpeg' };
  const audio = { contentType: 'audio/mp4' };
  const path = (uid, folder, file) => `users/${uid}/media/${folder}/${file}`;

  async function seed(uid, folder, file, metadata = jpeg) {
    await env.withSecurityRulesDisabled((ctx) =>
      uploadBytes(ref(ctx.storage(), path(uid, folder, file)), bytes(), metadata),
    );
  }

  it('lets a user upload, read, replace and delete their own pictures and audio', async () => {
    const photo = ref(alice(), path('alice', 'photos', 'a.jpg'));
    await assertSucceeds(uploadBytes(photo, bytes(), jpeg));
    await assertSucceeds(getBytes(photo));
    await assertSucceeds(uploadBytes(photo, bytes(32), jpeg));
    await assertSucceeds(deleteObject(photo));

    await assertSucceeds(
      uploadBytes(ref(alice(), path('alice', 'voices', 'v.m4a')), bytes(), audio),
    );
    await assertSucceeds(
      uploadBytes(ref(alice(), path('alice', 'moodboard', 'm.png')), bytes(), {
        contentType: 'image/png',
      }),
    );
  });

  it("keeps one user out of another's files", async () => {
    await seed('alice', 'photos', 'a.jpg');
    const target = path('alice', 'photos', 'a.jpg');
    await assertFails(getBytes(ref(bob(), target)));
    await assertFails(deleteObject(ref(bob(), target)));
    await assertFails(uploadBytes(ref(bob(), target), bytes(), jpeg));
    await assertFails(uploadBytes(ref(bob(), path('alice', 'photos', 'b.jpg')), bytes(), jpeg));
  });

  it("lets a user list their own media (deleting the account needs it) and nobody else's", async () => {
    await seed('alice', 'photos', 'a.jpg');
    await seed('alice', 'voices', 'v.m4a', audio);
    const root = (storage) => ref(storage, 'users/alice/media');
    const folder = (storage) => ref(storage, 'users/alice/media/photos');
    await assertSucceeds(listAll(root(alice())));
    await assertSucceeds(listAll(folder(alice())));
    await assertFails(listAll(root(bob())));
    await assertFails(listAll(folder(bob())));
    await assertFails(listAll(root(nobody())));
    await assertFails(listAll(ref(alice(), 'users/bob/media')));
    await assertFails(listAll(ref(alice(), 'users/alice')));
  });

  it('turns away anyone who is not signed in', async () => {
    await seed('alice', 'photos', 'a.jpg');
    const target = path('alice', 'photos', 'a.jpg');
    await assertFails(getBytes(ref(nobody(), target)));
    await assertFails(uploadBytes(ref(nobody(), target), bytes(), jpeg));
    await assertFails(deleteObject(ref(nobody(), target)));
  });

  it('refuses files larger than 5 MB and accepts exactly 5 MB', async () => {
    await assertFails(
      uploadBytes(ref(alice(), path('alice', 'photos', 'big.jpg')), bytes(MAX + 1), jpeg),
    );
    await assertSucceeds(
      uploadBytes(ref(alice(), path('alice', 'photos', 'edge.jpg')), bytes(MAX), jpeg),
    );
  });

  it('accepts only pictures and audio', async () => {
    const text = { contentType: 'text/plain' };
    const video = { contentType: 'video/mp4' };
    await assertFails(uploadBytes(ref(alice(), path('alice', 'photos', 'x.jpg')), bytes(), text));
    await assertFails(uploadBytes(ref(alice(), path('alice', 'photos', 'y.mp4')), bytes(), video));
  });

  it('accepts only the three media folders, directly under media', async () => {
    await assertFails(uploadBytes(ref(alice(), path('alice', 'videos', 'a.jpg')), bytes(), jpeg));
    await assertFails(uploadBytes(ref(alice(), 'users/alice/other/a.jpg'), bytes(), jpeg));
    await assertFails(uploadBytes(ref(alice(), 'users/alice/media/a.jpg'), bytes(), jpeg));
    await assertFails(
      uploadBytes(ref(alice(), 'users/alice/media/photos/deeper/a.jpg'), bytes(), jpeg),
    );
  });

  it('denies everything outside users/{uid}/media', async () => {
    await assertFails(uploadBytes(ref(alice(), 'public/a.jpg'), bytes(), jpeg));
    await assertFails(uploadBytes(ref(alice(), 'a.jpg'), bytes(), jpeg));
  });
});
