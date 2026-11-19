import 'package:sabbath_school_lessons/sabbath_school_lessons.dart';
import 'package:test/test.dart';

void main() {
  test('default client points at the fork and builds raw URLs', () {
    final client = SabbathSchoolClient();

    expect(client.owner, 'joshuamumbere');
    expect(client.repo, 'sabbath-school-lessons');
    expect(client.branch, 'stage');
    expect(
      client.rawUri('en/2026-01/info.yml').toString(),
      'https://raw.githubusercontent.com/joshuamumbere/sabbath-school-lessons/'
      'stage/src/en/2026-01/info.yml',
    );
    expect(
      client.apiUri('src/en').queryParameters['ref'],
      'stage',
    );
  });

  test('custom client configuration is respected', () {
    final client = SabbathSchoolClient(
      owner: 'Adventech',
      repo: 'sabbath-school-lessons',
      branch: 'master',
    );

    expect(
      client.rawUri('en/info.yml').toString(),
      'https://raw.githubusercontent.com/Adventech/sabbath-school-lessons/'
      'master/src/en/info.yml',
    );
    client.close();
  });
}
