import 'package:json_annotation/json_annotation.dart';

part 'verification_response.g.dart';

@JsonSerializable()
class VerificationResponse {
  @JsonKey(name: 'is_expired')
  final bool isExpired;

  @JsonKey(name: 'authentic_chip')
  final bool authenticChip;

  @JsonKey(name: 'authentic_content')
  final bool authenticContent;

  VerificationResponse({required this.isExpired, required this.authenticChip, required this.authenticContent});

  factory VerificationResponse.fromJson(Map<String, dynamic> json) => _$VerificationResponseFromJson(json);
  Map<String, dynamic> toJson() => _$VerificationResponseToJson(this);
}
