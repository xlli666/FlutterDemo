class Api {
  String baseUrl = 'http://';
  static Api instance;
  static Api getInstance() {
    if (null == instance) instance = new Api();
    return instance;
  }
}