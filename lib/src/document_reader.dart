import 'document.dart';
import 'lds/df1/efdg1.dart';
import 'lds/df1/efdg10.dart';
import 'lds/df1/efdg11.dart';
import 'lds/df1/efdg12.dart';
import 'lds/df1/efdg13.dart';
import 'lds/df1/efdg14.dart';
import 'lds/df1/efdg15.dart';
import 'lds/df1/efdg16.dart';
import 'lds/df1/efdg2.dart';
import 'lds/df1/efdg3.dart';
import 'lds/df1/efdg4.dart';
import 'lds/df1/efdg5.dart';
import 'lds/df1/efdg6.dart';
import 'lds/df1/efdg7.dart';
import 'lds/df1/efdg8.dart';
import 'lds/df1/efdg9.dart';
import 'lds/df1/efcom.dart';
import 'lds/df1/efsod.dart';
import 'types/data.dart';

abstract class DocumentReader {
  DocumentReader(this.document);

  final Document document;

  DocumentType get documentType => document.documentType;

  Future<EfCOM> readEfCOM() => document.readEfCOM();
  Future<EfSOD> readEfSOD() => document.readEfSOD();
  Future<EfDG1> readEfDG1() => document.readEfDG1();
  Future<EfDG2> readEfDG2() => _unsupported('EF.DG2');
  Future<EfDG3> readEfDG3() => _unsupported('EF.DG3');
  Future<EfDG4> readEfDG4() => _unsupported('EF.DG4');
  Future<EfDG5> readEfDG5() => _unsupported('EF.DG5');
  Future<EfDG6> readEfDG6() => _unsupported('EF.DG6');
  Future<EfDG7> readEfDG7() => _unsupported('EF.DG7');
  Future<EfDG8> readEfDG8() => _unsupported('EF.DG8');
  Future<EfDG9> readEfDG9() => _unsupported('EF.DG9');
  Future<EfDG10> readEfDG10() => _unsupported('EF.DG10');
  Future<EfDG11> readEfDG11() => _unsupported('EF.DG11');
  Future<EfDG12> readEfDG12() => _unsupported('EF.DG12');
  Future<EfDG13> readEfDG13() => _unsupported('EF.DG13');
  Future<EfDG14> readEfDG14() => _unsupported('EF.DG14');
  Future<EfDG15> readEfDG15() => _unsupported('EF.DG15');
  Future<EfDG16> readEfDG16() => _unsupported('EF.DG16');

  Future<T> _unsupported<T>(String fileName) {
    return Future.error(
      UnsupportedError(
          '${documentType.name} documents do not support reading $fileName'),
    );
  }

  static DocumentReader from(Document document) {
    switch (document.documentType) {
      case DocumentType.passport:
        return PassportReader(document as Passport);
      case DocumentType.driverLicence:
        return DrivingLicenceReader(document as DrivingLicence);
    }
  }
}

class DrivingLicenceReader extends DocumentReader {
  DrivingLicenceReader(DrivingLicence licence) : super(licence);
}

class PassportReader extends DocumentReader {
  PassportReader(Passport passport) : super(passport);

  Passport get _passport => document as Passport;

  @override
  Future<EfDG2> readEfDG2() => _passport.readEfDG2();
  @override
  Future<EfDG3> readEfDG3() => _passport.readEfDG3();
  @override
  Future<EfDG4> readEfDG4() => _passport.readEfDG4();
  @override
  Future<EfDG5> readEfDG5() => _passport.readEfDG5();
  @override
  Future<EfDG6> readEfDG6() => _passport.readEfDG6();
  @override
  Future<EfDG7> readEfDG7() => _passport.readEfDG7();
  @override
  Future<EfDG8> readEfDG8() => _passport.readEfDG8();
  @override
  Future<EfDG9> readEfDG9() => _passport.readEfDG9();
  @override
  Future<EfDG10> readEfDG10() => _passport.readEfDG10();
  @override
  Future<EfDG11> readEfDG11() => _passport.readEfDG11();
  @override
  Future<EfDG12> readEfDG12() => _passport.readEfDG12();
  @override
  Future<EfDG13> readEfDG13() => _passport.readEfDG13();
  @override
  Future<EfDG14> readEfDG14() => _passport.readEfDG14();
  @override
  Future<EfDG15> readEfDG15() => _passport.readEfDG15();
  @override
  Future<EfDG16> readEfDG16() => _passport.readEfDG16();
}
