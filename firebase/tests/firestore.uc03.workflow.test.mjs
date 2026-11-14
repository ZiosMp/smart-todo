// UC03 workflow tests: xem danh sach, tao, sua, luu tru va khoi phuc Board.
// Day la kiem thu Firestore Rules + luong du lieu; khong thay the widget test Flutter.
import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../..');
const rules = await readFile(path.join(root, 'firestore.rules'), 'utf8');
const emulator = (process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080').split(':');
const PROJECT_ID = 'demo-smart-todo';
const CREATED_AT = new Date('2026-10-01T00:00:00Z');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host: emulator[0],
      port: Number(emulator[1] || 8080),
      rules,
    },
  });
});

after(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

function userDb(uid, email = `${uid}@example.com`) {
  return env.authenticatedContext(uid, { email }).firestore();
}

async function seedBoard({
  boardId,
  ownerId = 'owner',
  memberIds = ['owner', 'member'],
  archivedAt = null,
  updatedAt = CREATED_AT,
  name = boardId,
} = {}) {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();

    await setDoc(doc(db, `boards/${boardId}`), {
      name,
      description: 'Board dung de kiem thu UC03',
      ownerId,
      memberIds,
      archivedAt,
      createdAt: CREATED_AT,
      updatedAt,
    });

    for (const uid of memberIds) {
      await setDoc(doc(db, `boards/${boardId}/members/${uid}`), {
        role: uid === ownerId ? 'owner' : 'member',
        displayName: uid,
        email: `${uid}@example.com`,
        joinedAt: CREATED_AT,
      });
    }
  });
}

function createBoardBatch(db, {
  boardId,
  name,
  description = '',
  uid = 'new-owner',
  email = 'new-owner@example.com',
} = {}) {
  const batch = writeBatch(db);
  const boardRef = doc(db, `boards/${boardId}`);

  batch.set(boardRef, {
    name,
    description,
    ownerId: uid,
    memberIds: [uid],
    archivedAt: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  batch.set(doc(db, `boards/${boardId}/members/${uid}`), {
    role: 'owner',
    displayName: 'New Owner',
    email,
    joinedAt: serverTimestamp(),
  });

  return batch;
}

test('UC03-01: Member xem duoc Board tham gia; danh sach chinh khong hien Board da luu tru', async () => {
  await seedBoard({ boardId: 'active-board', name: 'Board dang lam' });
  await seedBoard({
    boardId: 'archived-board',
    name: 'Board da luu tru',
    archivedAt: new Date('2026-10-02T00:00:00Z'),
  });
  await seedBoard({
    boardId: 'private-board',
    ownerId: 'someone-else',
    memberIds: ['someone-else'],
  });

  const db = userDb('member');
  const result = await assertSucceeds(
    getDocs(query(
      collection(db, 'boards'),
      where('memberIds', 'array-contains', 'member'),
    )),
  );

  const activeIds = result.docs
    .filter(board => board.data().archivedAt == null)
    .map(board => board.id);
  const archivedIds = result.docs
    .filter(board => board.data().archivedAt != null)
    .map(board => board.id);

  assert.deepEqual(activeIds, ['active-board']);
  assert.deepEqual(archivedIds, ['archived-board']);
  await assertFails(getDoc(doc(db, 'boards/private-board')));
});

test('UC03-02: Tao Board hop le va tao ho so Owner trong cung mot batch', async () => {
  const db = userDb('new-owner', 'new-owner@example.com');

  await assertSucceeds(createBoardBatch(db, {
    boardId: 'new-board',
    name: 'Board moi',
    description: 'Mo ta board moi',
  }).commit());

  const board = await assertSucceeds(getDoc(doc(db, 'boards/new-board')));
  const owner = await assertSucceeds(
    getDoc(doc(db, 'boards/new-board/members/new-owner')),
  );

  assert.equal(board.data().name, 'Board moi');
  assert.equal(board.data().description, 'Mo ta board moi');
  assert.equal(board.data().ownerId, 'new-owner');
  assert.deepEqual(board.data().memberIds, ['new-owner']);
  assert.equal(board.data().archivedAt, null);
  assert.equal(owner.data().role, 'owner');
  assert.equal(owner.data().email, 'new-owner@example.com');

  // Ranh gioi do dai theo UC03: 1 va 100 ky tu hop le; 0 va 101 khong hop le.
  await assertSucceeds(createBoardBatch(db, {
    boardId: 'one-char-name',
    name: 'A',
  }).commit());
  await assertSucceeds(createBoardBatch(db, {
    boardId: 'max-name',
    name: 'B'.repeat(100),
  }).commit());
  await assertFails(createBoardBatch(db, {
    boardId: 'empty-name',
    name: '',
  }).commit());
  await assertFails(createBoardBatch(db, {
    boardId: 'too-long-name',
    name: 'C'.repeat(101),
  }).commit());
});

test('UC03-03: Owner sua duoc ten va mo ta; Member khong sua duoc', async () => {
  await seedBoard({ boardId: 'edit-board' });

  const ownerDb = userDb('owner');
  const memberDb = userDb('member');
  const boardRef = doc(ownerDb, 'boards/edit-board');

  await assertSucceeds(updateDoc(boardRef, {
    name: 'Ten Board da sua',
    description: 'Mo ta da cap nhat',
    updatedAt: serverTimestamp(),
  }));

  const updated = await assertSucceeds(getDoc(boardRef));
  assert.equal(updated.data().name, 'Ten Board da sua');
  assert.equal(updated.data().description, 'Mo ta da cap nhat');

  await assertFails(updateDoc(doc(memberDb, 'boards/edit-board'), {
    name: 'Member tu sua',
    description: 'Khong duoc phep',
    updatedAt: serverTimestamp(),
  }));
});

test('UC03-04: Owner luu tru Board; Board bi an khoi danh sach dang hoat dong nhung khong bi xoa', async () => {
  await seedBoard({ boardId: 'archive-board' });

  const ownerDb = userDb('owner');
  const boardRef = doc(ownerDb, 'boards/archive-board');

  await assertSucceeds(updateDoc(boardRef, {
    archivedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));

  const archived = await assertSucceeds(getDoc(boardRef));
  assert.ok(archived.data().archivedAt, 'archivedAt phai duoc ghi nhan');
  assert.equal(archived.exists(), true, 'Luu tru khong duoc xoa Board');

  const memberBoards = await assertSucceeds(
    getDocs(query(
      collection(userDb('member'), 'boards'),
      where('memberIds', 'array-contains', 'member'),
    )),
  );
  const activeIds = memberBoards.docs
    .filter(board => board.data().archivedAt == null)
    .map(board => board.id);

  assert.equal(activeIds.includes('archive-board'), false);
});

test('UC03-05: Owner khoi phuc Board; Board tro lai danh sach chinh', async () => {
  await seedBoard({
    boardId: 'restore-board',
    archivedAt: new Date('2026-10-02T00:00:00Z'),
  });

  const memberDb = userDb('member');
  const ownerDb = userDb('owner');
  const boardRef = doc(ownerDb, 'boards/restore-board');

  // Member khong co quyen khoi phuc.
  await assertFails(updateDoc(doc(memberDb, 'boards/restore-board'), {
    archivedAt: null,
    updatedAt: serverTimestamp(),
  }));

  await assertSucceeds(updateDoc(boardRef, {
    archivedAt: null,
    updatedAt: serverTimestamp(),
  }));

  const restored = await assertSucceeds(getDoc(boardRef));
  assert.equal(restored.data().archivedAt, null);

  const activeBoards = await assertSucceeds(
    getDocs(query(
      collection(ownerDb, 'boards'),
      where('memberIds', 'array-contains', 'owner'),
      where('archivedAt', '==', null),
    )),
  );
  assert.deepEqual(activeBoards.docs.map(board => board.id), ['restore-board']);
});
