import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zephyr/widgets/image_recovery_region.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';

class PictureRecoveryRegion extends StatelessWidget {
  const PictureRecoveryRegion({
    super.key,
    required this.bloc,
    required this.child,
  });
  final PictureBloc bloc;
  final Widget child;
  @override
  Widget build(BuildContext context) => ImageRecoveryRegion(
    onActiveChanged: bloc.setRecoveryActive,
    onPageRefreshed: () => unawaited(bloc.retryFailed()),
    child: child,
  );
}
