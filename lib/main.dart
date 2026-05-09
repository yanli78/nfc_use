import 'package:flutter/material.dart';
import 'package:nfc_use/pages/Main/index.dart';

// 1. 程序的唯一入口点
void main() {
  runApp(getRootWidget());
}

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
