enum DataGroups { dg1, dg2, dg3, dg4, dg5, dg6, dg7, dg8, dg9, dg10, dg11, dg12, dg13, dg14, dg15, dg16 }

extension GetNameExtension on DataGroups {
  String getName() {
    return switch (this) {
      DataGroups.dg1 => 'DG1',
      DataGroups.dg2 => 'DG2',
      DataGroups.dg3 => 'DG3',
      DataGroups.dg4 => 'DG4',
      DataGroups.dg5 => 'DG5',
      DataGroups.dg6 => 'DG6',
      DataGroups.dg7 => 'DG7',
      DataGroups.dg8 => 'DG8',
      DataGroups.dg9 => 'DG9',
      DataGroups.dg10 => 'DG10',
      DataGroups.dg11 => 'DG11',
      DataGroups.dg12 => 'DG12',
      DataGroups.dg13 => 'DG13',
      DataGroups.dg14 => 'DG14',
      DataGroups.dg15 => 'DG15',
      DataGroups.dg16 => 'DG16',
    };
  }
}
