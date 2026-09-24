import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/office_text.dart';

Uint8List _fixture(String name) =>
    File('test/fixtures/office/$name').readAsBytesSync();

void main() {
  // Written by two different producers (openpyxl, LibreOffice): they lay out
  // the ZIP, the shared strings and the cell references differently.
  for (final name in ['book.xlsx', 'book_libreoffice.xlsx']) {
    test('a workbook becomes CSV, sheet by sheet ($name)', () {
      final result = officeDocumentAsText(name, _fixture(name));
      expect(result.sections, 2);
      expect(result.truncated, isFalse);
      final lines = result.text.split('\n');
      expect(lines.first, '# Sheet: Accounts');
      expect(lines[1], 'Name,Balance,Active,Note');
      // Commas and quotes are escaped the way any CSV reader expects.
      expect(lines[2], '"Savings, main",1520.5,TRUE,"says ""hi"""');
      expect(lines[3], 'Credit,-300,FALSE');
      // A cell far from the others keeps its column.
      expect(lines[4], ',,,,,far cell');
      expect(result.text, contains('# Sheet: Offers\nOffer,Months\nIPP,12'));
      expect(result.lines, 6);
    });
  }

  test('a Word document becomes its paragraphs', () {
    final result = officeDocumentAsText('doc.docx', _fixture('doc.docx'));
    expect(result.text, 'First paragraph.\n\nSecond\twith tab.');
    expect(result.lines, 2);
  });

  test('a file that only has the name is refused, not half-read', () {
    expect(
      () => officeDocumentAsText(
        'old.xlsx',
        Uint8List.fromList(List.filled(64, 7)),
      ),
      throwsFormatException,
    );
    // A real ZIP that is not a workbook.
    expect(
      () => officeDocumentAsText('notes.xlsx', _fixture('doc.docx')),
      throwsFormatException,
    );
  });

  test('which files are read this way', () {
    expect(isOfficeDocument('Budget.XLSX'), isTrue);
    expect(isOfficeDocument('macro.xlsm'), isTrue);
    expect(isOfficeDocument('brief.docx'), isTrue);
    expect(isOfficeDocument('legacy.xls'), isFalse);
    expect(isOfficeDocument('notes.txt'), isFalse);
  });
}
