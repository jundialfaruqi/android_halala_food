class AuthTokensModel {
  final String accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;

  AuthTokensModel({
    required this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
  });

  factory AuthTokensModel.fromJson(Map<String, dynamic> json) {
    return AuthTokensModel(
      accessToken: json['access_token']?.toString() ?? json['token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString(),
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      expiresIn: json['expires_in'] is int
          ? json['expires_in']
          : int.tryParse(json['expires_in']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_in': expiresIn,
    };
  }
}
