import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcmrtd/vcmrtd.dart';
import 'package:vcmrtdapp/widgets/pages/document_selection_screen.dart';

// Can be used to globally check whether advanced mode is turned on
final advancedModeProvider = StateProvider((ref) => false);

// Can be used globally to access the activeAuthentication parameter
final activeAuthenticationProvider = StateProvider((ref) => false);

// Can be used globally to access the passiveAuthentication parameter
final passiveAuthenticationProvider = StateProvider((ref) => true);

// Can be used globally to access the authmethod parameter
final authMethodProvider = StateProvider((ref) => AuthMethod.bac);

final passportDataGroupsProvider = StateNotifierProvider<PassportDataGroupsNotifier, ActiveDataGroups>((ref) {
  return PassportDataGroupsNotifier();
});

final drivingLicenseDataGroupsProvider = StateNotifierProvider<DrivingLicenseDataGroupsNotifier, ActiveDataGroups>((
  ref,
) {
  return DrivingLicenseDataGroupsNotifier();
});

// Can be used globally to access the exportToJson parameter
final exportToJsonProvider = StateProvider((ref) => false);

class ActiveDataGroups {
  final Set<DataGroups> activeDataGroups;

  const ActiveDataGroups({required this.activeDataGroups});
}

class PassportDataGroupsNotifier extends StateNotifier<ActiveDataGroups> {
  PassportDataGroupsNotifier()
    : super(
        const ActiveDataGroups(
          // default active datagroups settings for passport
          activeDataGroups: {
            DataGroups.dg1,
            DataGroups.dg2,
            DataGroups.dg3,
            DataGroups.dg4,
            DataGroups.dg5,
            DataGroups.dg6,
            DataGroups.dg7,
            DataGroups.dg8,
            DataGroups.dg9,
            DataGroups.dg10,
            DataGroups.dg11,
            DataGroups.dg12,
            DataGroups.dg13,
            DataGroups.dg14,
            DataGroups.dg15,
            DataGroups.dg16,
          },
        ),
      );

  void toggleDataGroup(DataGroups dg, bool setActive) {
    final newSet = Set<DataGroups>.from(state.activeDataGroups);

    if (newSet.contains(dg) && !setActive) {
      newSet.remove(dg);
    } else if (!newSet.contains(dg) && setActive) {
      newSet.add(dg);
    }

    state = ActiveDataGroups(activeDataGroups: newSet);
  }
}

class DrivingLicenseDataGroupsNotifier extends StateNotifier<ActiveDataGroups> {
  DrivingLicenseDataGroupsNotifier()
    : super(
        const ActiveDataGroups(
          // default active datagroups settings for driving license
          // Skipping DG5 due to bad signature image quality
          activeDataGroups: {DataGroups.dg1, DataGroups.dg6, DataGroups.dg11, DataGroups.dg12, DataGroups.dg13},
        ),
      );

  void toggleDataGroup(DataGroups dg, bool setActive) {
    final newSet = Set<DataGroups>.from(state.activeDataGroups);

    if (newSet.contains(dg) && !setActive) {
      newSet.remove(dg);
    } else if (!newSet.contains(dg) && setActive) {
      newSet.add(dg);
    }

    state = ActiveDataGroups(activeDataGroups: newSet);
  }
}
