//返回App根级组件
import 'package:flutter/material.dart';
import 'package:nfc_use/pages/Main/index.dart';

Widget getRootWidget() {
  return MaterialApp(
    title: '数字钱包',
    debugShowCheckedModeBanner: false,
    //命名路由
    initialRoute: "/", //初始路由
    routes: getRouteConfig(), //路由配置
  );
}

//返回该App的路由配置
Map<String, Widget Function(BuildContext)> getRouteConfig() {
  return {
    "/": (context) => MainPage(), //主页路由
  };
}
