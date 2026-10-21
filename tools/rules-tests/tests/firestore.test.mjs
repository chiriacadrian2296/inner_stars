import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, deleteDoc, collection, getDocs } from 'firebase/firestore';

const rules = readFileSync(new URL('../../../firestore.rules', import.meta.url), 'utf8');

describe('firestore.rules', () => {
  let env;

  before(async () => {
    env = await initializeTestEnvironment({
      projectId: 'demo-inner-stars',
      firestore: { rules, host: '127.0.0.1', port: 8080 },
    });
  });

  after(() => env.cleanup());
  beforeEach(() => env.clearFirestore());

  const alice = () => env.authenticatedContext('alice').firestore();
  const bob = () => env.authenticatedContext('bob').firestore();
  const nobody = () => env.unauthenticatedContext().firestore();
  const record = { id: '1', updatedAt: '2026-01-01T00:00:00.000Z', deleted: false, data: '{}' };

  it('lets a user write, read and delete their own records', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/stars/1'), record));
    await assertSucceeds(getDoc(doc(alice(), 'users/alice/stars/1')));
    await assertSucceeds(getDocs(collection(alice(), 'users/alice/stars')));
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice/stars/1')));
  });

  it('reaches every collection under the user, however deep', async () => {
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/moodboard/m1'), record));
    await assertSucceeds(setDoc(doc(alice(), 'users/alice/settings/a/b/c'), record));
  });

  it("keeps one user out of another's records", async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'users/alice/stars/1'), record),
    );
    await assertFails(getDoc(doc(bob(), 'users/alice/stars/1')));
    await assertFails(getDocs(collection(bob(), 'users/alice/stars')));
    await assertFails(setDoc(doc(bob(), 'users/alice/stars/1'), record));
    await assertFails(setDoc(doc(bob(), 'users/alice/stars/2'), record));
    await assertFails(deleteDoc(doc(bob(), 'users/alice/stars/1')));
  });

  it('turns away anyone who is not signed in', async () => {
    await assertFails(getDoc(doc(nobody(), 'users/alice/stars/1')));
    await assertFails(setDoc(doc(nobody(), 'users/alice/stars/1'), record));
  });

  it('denies everything outside users/{uid}', async () => {
    await assertFails(setDoc(doc(alice(), 'public/notice'), record));
    await assertFails(getDoc(doc(alice(), 'public/notice')));
    await assertFails(setDoc(doc(alice(), 'other/alice/stars/1'), record));
  });

  it("does not let a user name themselves as someone else", async () => {
    await assertFails(setDoc(doc(bob(), 'users/alice/profile/me'), record));
    await assertSucceeds(setDoc(doc(bob(), 'users/bob/profile/me'), record));
  });
});
