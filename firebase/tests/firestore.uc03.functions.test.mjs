import test, { after, before, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
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

// This suite verifies the five UC03 board data operations against the
// project's real Firestore Security Rules running in the Emulator.
const here = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(here, '../..');
const rules = await readFile(path.join(projectRoot, 'firestore.rules'), 'utf8');
const [emulatorHost, emulatorPort] = (
  process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080'
).split(':');

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-smart-todo',
    firestore: {
      host: emulatorHost,
      port: Number(emulatorPort || 8080),
      rules,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function authenticatedDb(uid, email = `${uid}@example.com`) {
  return testEnv.authenticatedContext(uid, { email }).firestore();
}

// Seed only test data. Security Rules are bypassed here intentionally so each
// test can begin from a known state; the operation under test uses normal rules.
async function seedBoard({
  boardId = 'uc03-board',
  ownerId = 'owner',
  memberIds = ['owner', 'member'],
  name = 'Board UC03',
  description = 'Board dùng để kiểm thử',
  archivedAt = null,
} = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `boards/${boardId}`), {
      name,
      description,
      ownerId,
      memberIds,
      archivedAt,
      createdAt: new Date('2026-11-01T00:00:00.000Z'),
      updatedAt: new Date('2026-11-01T00:00:00.000Z'),
    });
  });
}

test('UC03-F1: người dùng xem được danh sách board mình tham gia', async () => {
  await seedBoard({
    boardId: 'board-active',
    ownerId: 'owner',
    memberIds: ['owner', 'member'],
  });
  await seedBoard({
    boardId: 'board-archived',
    ownerId: 'another-owner',
    memberIds: ['another-owner', 'owner'],
    archivedAt: new Date('2026-11-02T00:00:00.000Z'),
  });
  await seedBoard({
    boardId: 'board-not-accessible',
    ownerId: 'someone-else',
    memberIds: ['someone-else'],
  });

  const db = authenticatedDb('owner');
  const result = await assertSucceeds(
    getDocs(
      query(
        collection(db, 'boards'),
        where('memberIds', 'array-contains', 'owner'),
      ),
    ),
  );

  const ids = result.docs.map((snapshot) => snapshot.id).sort();
  assert.deepEqual(ids, ['board-active', 'board-archived']);

  const activeBoards = result.docs.filter(
    (snapshot) => snapshot.data().archivedAt == null,
  );
  const archivedBoards = result.docs.filter(
    (snapshot) => snapshot.data().archivedAt != null,
  );

  assert.deepEqual(activeBoards.map((snapshot) => snapshot.id), ['board-active']);
  assert.deepEqual(archivedBoards.map((snapshot) => snapshot.id), ['board-archived']);
});

test('UC03-F2: tạo board và hồ sơ Owner trong cùng một batch', async () => {
  const uid = 'new-owner';
  const email = 'new-owner@example.com';
  const db = authenticatedDb(uid, email);
  const boardId = 'board-created-by-test';
  const batch = writeBatch(db);

  batch.set(doc(db, `boards/${boardId}`), {
    name: 'Board mới',
    description: 'Board được tạo từ bài kiểm thử',
    ownerId: uid,
    memberIds: [uid],
    archivedAt: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  batch.set(doc(db, `boards/${boardId}/members/${uid}`), {
    role: 'owner',
    displayName: 'Chủ board thử nghiệm',
    email,
    joinedAt: serverTimestamp(),
  });

  await assertSucceeds(batch.commit());

  const savedBoard = await assertSucceeds(getDoc(doc(db, `boards/${boardId}`)));
  const savedOwner = await assertSucceeds(
    getDoc(doc(db, `boards/${boardId}/members/${uid}`)),
  );

  assert.equal(savedBoard.exists(), true);
  assert.equal(savedBoard.data().name, 'Board mới');
  assert.equal(savedBoard.data().ownerId, uid);
  assert.deepEqual(savedBoard.data().memberIds, [uid]);
  assert.equal(savedBoard.data().archivedAt, null);

  assert.equal(savedOwner.exists(), true);
  assert.equal(savedOwner.data().role, 'owner');
  assert.equal(savedOwner.data().email, email);
});

test('UC03-F3: Owner sửa tên và mô tả board', async () => {
  await seedBoard();

  const db = authenticatedDb('owner');
  const boardRef = doc(db, 'boards/uc03-board');

  await assertSucceeds(
    updateDoc(boardRef, {
      name: 'Board đã chỉnh sửa',
      description: 'Mô tả sau khi cập nhật',
      updatedAt: serverTimestamp(),
    }),
  );

  const saved = await assertSucceeds(getDoc(boardRef));
  assert.equal(saved.data().name, 'Board đã chỉnh sửa');
  assert.equal(saved.data().description, 'Mô tả sau khi cập nhật');
  assert.equal(saved.data().ownerId, 'owner');
});

test('UC03-F4: lưu trữ board mà không xóa dữ liệu', async () => {
  await seedBoard();

  const db = authenticatedDb('owner');
  const boardRef = doc(db, 'boards/uc03-board');

  await assertSucceeds(
    updateDoc(boardRef, {
      archivedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  );

  const archived = await assertSucceeds(getDoc(boardRef));
  assert.equal(archived.exists(), true);
  assert.ok(archived.data().archivedAt);
  assert.equal(archived.data().name, 'Board UC03');
});

test('UC03-F5: khôi phục board đã lưu trữ', async () => {
  await seedBoard({
    archivedAt: new Date('2026-11-02T00:00:00.000Z'),
  });

  const db = authenticatedDb('owner');
  const boardRef = doc(db, 'boards/uc03-board');

  await assertSucceeds(
    updateDoc(boardRef, {
      archivedAt: null,
      updatedAt: serverTimestamp(),
    }),
  );

  const restored = await assertSucceeds(getDoc(boardRef));
  assert.equal(restored.exists(), true);
  assert.equal(restored.data().archivedAt, null);
  assert.equal(restored.data().name, 'Board UC03');
});

// Keep one negative-access assertion in this functional suite as a guard:
// a user outside the board cannot obtain the same board document.
test('UC03-F: người ngoài board không thể đọc board', async () => {
  await seedBoard();

  const outsiderDb = authenticatedDb('outsider');
  await assertFails(getDoc(doc(outsiderDb, 'boards/uc03-board')));
});
