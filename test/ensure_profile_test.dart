import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurly/services/auth_service.dart';

void main() {
  late FakeFirebaseFirestore fs;
  setUp(() => fs = FakeFirebaseFirestore());

  Future<void> ensure({String name = 'Sam'}) => ensureUserProfileDoc(
        fs,
        uid: 'u1',
        displayName: name,
        email: 'sam@example.com',
        now: DateTime(2026, 11, 17),
      );

  test('creates a missing profile (interrupted sign-up, Lead L1)', () async {
    await ensure();
    final doc = await fs.collection('users').doc('u1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['displayName'], 'Sam');
    expect(doc.data()!['email'], 'sam@example.com');
    expect(doc.data()!['isPro'], false);
    expect(doc.data()!.containsKey('householdId'), isFalse);
  });

  test('leaves an existing profile alone (keeps householdId, name)', () async {
    await fs.collection('users').doc('u1').set({
      'uid': 'u1',
      'displayName': 'Original',
      'householdId': 'h1',
      'createdAt': '2026-01-01T00:00:00.000',
    });
    await ensure(name: 'Other');
    final data = (await fs.collection('users').doc('u1').get()).data()!;
    expect(data['displayName'], 'Original');
    expect(data['householdId'], 'h1');
    expect(data['createdAt'], '2026-01-01T00:00:00.000');
  });

  test('idempotent: calling twice writes once', () async {
    await ensure();
    await ensure(name: 'Changed');
    final data = (await fs.collection('users').doc('u1').get()).data()!;
    expect(data['displayName'], 'Sam');
  });
}
