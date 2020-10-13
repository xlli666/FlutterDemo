import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_app_demo_java/common/Api.dart';

class HttpUtil {
  Dio dio;
  BaseOptions options;
  CancelToken cancelToken = CancelToken();
  static HttpUtil instance;

  static HttpUtil getInstance() {
    if (null == instance) instance = HttpUtil();
    return instance;
  }

  CookieJar cookieJar = CookieJar();

  /*
   * config and create
   */
  HttpUtil() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: Api.getInstance().baseUrl,
      //连接服务器超时时间，单位 毫秒
      connectTimeout: 50000,
      //响应流上前后两次接受到数据的间隔，单位 毫秒
      receiveTimeout: 30000,
      //Http请求头
      headers: {
        'version': '1.0.0',
        'X-Requested-With': 'XMLHttpRequest',
      },
      //请求的Content-Type，默认值是[ContentType.json]. 也可以用ContentType.parse('application/x-www-form-urlencoded')
      contentType: ContentType.json,
      //表示期望以那种格式(方式)接受响应数据。接受四种类型 `json`, `stream`, `plain`, `bytes`. 默认值是 `json`,
      responseType: ResponseType.json,
    );
    dio = Dio(options);

    //Cookie管理
    dio.interceptors.add(CookieManager(cookieJar));

    //添加拦截器
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (RequestOptions options) {
      print('请求之前');
      Loading.before(options.uri);
      return options;
    }, onResponse: (Response response) {
      print('响应之前');
      /* 延迟2秒返回数据
      Future.delayed(Duration(seconds: 3), () {
        Loading.complete(response.request.uri );
        return response;
      }); */
      Loading.complete(response.request.uri);
      return response;
    }, onError: (DioError error) {
      print('错误之前');
      Loading.complete(error.request.uri);
      return error;
    }));
    // 添加日志
    dio.interceptors.add(SaveLogInterceptor());
  }

  /*
   * get请求
   */
  get(url, {data, options, cancelToken}) async {
    Response response;
    try {
      response = await dio.get(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
      if (null == response.data || response.data.toString().isEmpty) {
        //fireLogin(response.request.uri);
      }
    } on DioError catch (e) {
      //print('get error---------$e');
      formatError(e);
    }
    return response;
  }

  /*
   * post请求
   */
  post(url, {data, options, cancelToken, postForm}) async {
    Response response;
    try {
      response = await dio.post(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
        data: postForm,
      );
      if (null == response.data || response.data.toString().isEmpty) {
        //fireLogin(response.request.uri);
      }
    } on DioError catch (e) {
      //print('post error---------$e');
      formatError(e);
    }
    return response;
  }

  /*
   * 下载文件
   */
  downloadFile(urlPath, savePath, {onRecProgress}) async {
    Response response;
    try {
      response = await dio.download(
        urlPath,
        savePath,
        onReceiveProgress: (int count, int total) {
          if (onRecProgress != null) {
            onRecProgress(count, total);
          }
          //进度
          print('$count $total');
        },
      );
      if (null == response.data || response.data.toString().isEmpty) {
        //fireLogin(response.request.uri);
      }
    } on DioError catch (e) {
      //print('downloadFile error---------$e');
      formatError(e);
    }
    return response;
  }

  /*
   * 取消请求
   *
   * 同一个cancel token 可以用于多个请求，当一个cancel token取消时，所有使用该cancel token的请求都会被取消。
   * 所以参数可选
   */
  void cancelRequests(CancelToken token) {
    token.cancel('cancelled');
  }

  /*
   * error统一处理
   */
  formatError(DioError e) {
    String errorDesc;
    String errorCode = '';
    if (null != e.response && null != e.response.statusCode) {
      errorCode = ' [' + e.response.statusCode.toString() + ']';
    }
    if (e.type == DioErrorType.CONNECT_TIMEOUT) {
      // It occurs when url is opened timeout.
      print('连接超时');
      errorDesc = '连接超时' + errorCode;
    } else if (e.type == DioErrorType.SEND_TIMEOUT) {
      // It occurs when url is sent timeout.
      print('请求超时');
      errorDesc = '请求超时' + errorCode;
    } else if (e.type == DioErrorType.RECEIVE_TIMEOUT) {
      //It occurs when receiving timeout
      print('响应超时');
      errorDesc = '响应超时' + errorCode;
    } else if (e.type == DioErrorType.RESPONSE) {
      // When the server response, but with a incorrect status, such as 404, 503...
      print('状态异常');
      errorDesc = '状态异常' + errorCode;
    } else if (e.type == DioErrorType.CANCEL) {
      // When the request is cancelled, dio will throw a error with this type.
      print('请求取消');
      errorDesc = '请求取消' + errorCode;
    } else {
      //DEFAULT Default error type, Some other Error. In this case, you can read the DioError.error if it is not null.
      print('服务器异常');
      errorDesc = '服务器异常' + errorCode;
    }

    // MQTT请求和登出请求不弹出异常
    if (e.response == null) {
      EMToast.show(errorDesc);
    } else if (!e.request.uri.toString().contains(Api.E_MQTT)
        && !e.request.uri.toString().contains(Api.LOGOUT)){
      try {
        var errorInfo = jsonDecode(e.response.data);
        String errorMsg = errorInfo['message'].toString();
        String showMsg = errorMsg.indexOf('###') == -1
            ? errorMsg
            : errorMsg.replaceRange(0, errorMsg.indexOf('###'), '');
        if (showMsg.indexOf(',') != -1 && showMsg.substring(0, showMsg.indexOf(',')) == '会话超时') {
          fireLogin(e.request.uri, showMsg.substring(0, 4),);
        } else if (e.response.statusCode == 501){
          HttpError.showView(showMsg);
        } else {
          EMToast.show(showMsg.substring(0, showMsg.lastIndexOf('<')));
        }
      } catch(err) {
        HttpError.showView(e.response.data);
      }
    } else {
      print('***EMAN***'+jsonDecode(e.response.data)['message'].toString());
    }
  }

  // 退出到登录页
  fireLogin(Uri uri, String msg) {
    if (!uri.toString().contains(Api.LOGIN) &&
        !uri.toString().contains(Api.LOGIN2) &&
        !uri.toString().contains(Api.LOGOUT) &&
        !uri.toString().contains(Api.E_MQTT)) {
      EMToast.show(msg + '！请重新登录');
      GlobalEventBus().event.fire(LoginEvent());
    }
    /* 除登录、退出和...请求，其他请求cookie异常时回到登录页 -- 1.没有cookie、返回 2.cookie获取失败、返回 3.cookie超时、返回
    bool cookieError = false;
    if (!uri.toString().contains(Api.LOGIN)) {
      List<Cookie> cookieList = cookieJar.loadForRequest(uri);
      for (int i = 0; i < cookieList.length; i++) {
        if ('token_em' == cookieList[i].name && null != cookieList[i].expires && cookieList[i].expires.isAfter(DateTime.now())) {
          cookieError = false;
          break;
        } else {
          cookieError = true;
          continue;
        }
      }
    }
    if (!cookieError) {
      Loading.complete(uri);
      GlobalEventBus().event.fire(LoginEvent(text: '12312'));
    }*/
  }
}

class SaveLogInterceptor extends Interceptor {
  final dateTime = formatDate(DateTime.now(), [yyyy, '-', mm, '-', dd , ' ', HH, ':', nn, ':', ss]);
  final fileSuffix = formatDate(DateTime.now(), [yyyy, mm, dd]);
  @override
  FutureOr<dynamic> onRequest(RequestOptions options) {
    if (CommUtil.isInDebugMode) {
      print('*** Request Path *** ---------${options.path}');
      print('*** Request Param ***');
      print(options.queryParameters);
    } else {
      StringBuffer buffer = StringBuffer();
      buffer.write('---------$dateTime---------\n');
      buffer.write('*** Request Path *** ---------${options.path}\n');
      buffer.write('*** Request Param ***\n');
      buffer.write('${options.queryParameters}\n');
      String text = buffer.toString();
      CommUtil.saveFile(text, subPath: 'log', fileName: 'data$fileSuffix');
    }
  }

  @override
  FutureOr<dynamic> onResponse(Response response) {
    if (CommUtil.isInDebugMode) {
      // response.data; 响应体
      // response.headers; 响应头
      // response.request; 请求体
      // response.statusCode; 状态码
      print('*** Response Status Code *** ---------${response.statusCode}');
      print("*** Response Data ***");
      print(response.data);
    } else {
      StringBuffer buffer = StringBuffer();
      buffer.write('---------$dateTime---------\n');
      buffer.write('*** Response Status Code *** ---------${response.statusCode}\n');
      buffer.write('*** Response Data ***\n');
      buffer.write('${response.data}\n');
      String text = buffer.toString();
      CommUtil.saveFile(text, subPath: 'log', fileName: 'data$fileSuffix');
    }
  }

  @override
  FutureOr<dynamic> onError(DioError err) {
    if (CommUtil.isInDebugMode) {
      print('*** Dio Error ***');
      print(err);
      if (err.response != null) {
        print(err.response.data);
      }
    } else {
      StringBuffer buffer = StringBuffer();
      buffer.write('---------$dateTime---------\n');
      buffer.write('*** Dio Error ***\n');
      buffer.write('$err\n');
      if (err.response != null) {
        buffer.write('${err.response.data}\n');
      }
      String text = buffer.toString();
      CommUtil.saveFile(text, subPath: 'log', fileName: 'data$fileSuffix');
    }
  }
}
