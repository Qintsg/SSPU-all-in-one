/*
 * SSPU 微信公众号推荐列表 — 来源于校园+微信矩阵
 * 数据通过 CampusPlus API 获取（appId=52, newMediaType=16）
 * @Project : SSPU-all-in-one
 * @File : sspu_wechat_accounts.dart
 * @Author : Qintsg
 * @Date : 2026-07-21
 */

/// SSPU 官方认可的微信公众号信息
class SspuWechatAccount {
  /// 公众号名称
  final String name;

  /// 微信号（部分为中文名）
  final String wxAccount;

  /// 头像图片 URL
  final String iconUrl;

  /// 公众号介绍文章链接
  final String articleUrl;

  const SspuWechatAccount({
    required this.name,
    required this.wxAccount,
    required this.iconUrl,
    required this.articleUrl,
  });
}

/// 来自校园+微信矩阵的 SSPU 官方公众号列表
/// 数据源：https://weixin.campusplus.com/sspu/youthmedia
const List<SspuWechatAccount> sspuWechatAccounts = [
  SspuWechatAccount(
    name: '上海第二工业大学',
    wxAccount: '上海第二工业大学',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-11/75289ced19911218d56d5fb6cf44e0f3_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/vALs8F-0cEel3S5AU6l5Vw',
  ),
  SspuWechatAccount(
    name: 'SSPU智控学院',
    wxAccount: 'SSPU智控学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-09/cc9c1744de05a60836f70e49a920d997_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/gNnGdNODbXmGFt0I1NwPUQ',
  ),
  SspuWechatAccount(
    name: '计信智音',
    wxAccount: '计信智音',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-09/8d4721cbd2dd4f9e0cdac05db223f709_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/WHdx46muaWTXV4NjtwWGCA',
  ),
  SspuWechatAccount(
    name: 'SSPU资环学院',
    wxAccount: 'SSPU资环学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/22-05/2ec9fc88a8dd2725d49223938473c1ff_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/X-6beZwHeMBciYh3JyrInw',
  ),
  SspuWechatAccount(
    name: 'SSPU能材学院',
    wxAccount: 'SSPU能材学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-09/edc9cda6685d59c7950b19b72f0a4228_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/IB6nZCYmgU26OIkc36TwfA',
  ),
  SspuWechatAccount(
    name: 'SSPU集成电路学院',
    wxAccount: 'SSPU集成电路学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/25-12/edfb8b6d120506737f7b7e2970ec3a59_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/YetRu_azLLOfhpsym33jWA',
  ),
  SspuWechatAccount(
    name: 'SSPU医工学院',
    wxAccount: 'SSPU医工学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/26-04/b26e388b9de1d6444b2e799625e73c58_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/MP-ArSXVcOXOfjDI2TrXnQ',
  ),
  SspuWechatAccount(
    name: 'SSPU经管之声',
    wxAccount: 'sspujingguanzhisheng',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/6df73622-c867-4881-b67c-73fad41310e3.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/1_wm4ArfrIDIGIf5STiAEg',
  ),
  SspuWechatAccount(
    name: 'SSPU文传新语',
    wxAccount: 'SSPU文传新语',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/22-09/1cf73744f2e6231a8da85d7ea3977d06_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/tGL1oDCt5wy1Gg1ajf4rmg',
  ),
  SspuWechatAccount(
    name: 'SSPU统观数理',
    wxAccount: 'SSPU统观数理',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/22-11/18dbd06491b9aecb689a36de034e872e_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/6M_8Xi5PmnTBmT3HY4p0Cg',
  ),
  SspuWechatAccount(
    name: 'SSPU艺术与设计学院',
    wxAccount: 'SSPU艺术与设计学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-06/71d51238ea1826ec030c497f9e9479ca_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/8LihN9qRpK3O-drQdUn_NA',
  ),
  SspuWechatAccount(
    name: '职业技术教师教育学院',
    wxAccount: '职业技术教师教育学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-11/b9a261daeadd824a9d044c8d0ed9bdc6_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/abtPEJO0L64-_vsvXyOgpg',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学马克思主义学院',
    wxAccount: '上海第二工业大学马克思主义学院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-03/c495bb1a095c45b7890661c5a7b48a51_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Scl1fMEeIOxb1bkbVgYomw',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学继续教育学院',
    wxAccount: 'sspucce',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/61305682-3fa3-450b-a074-38e66b40d187.png',
    articleUrl: 'https://mp.weixin.qq.com/s/Lm3gH-H2L1Tn197DD3NNvQ',
  ),
  SspuWechatAccount(
    name: 'SSPU艺梦',
    wxAccount: 'SSPU艺梦',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/639793f9-081a-47cb-a50c-4bfc3ebf83b4.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/icPmJkbCf5vuwTDxQknvWQ',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学区域国别研究院',
    wxAccount: '上海第二工业大学区域国别研究院',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/25-12/63b91411e03576b7a5c061d060a845b4_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Kj6tCM9I9srfo-jZbtVy7A',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学图书馆',
    wxAccount: '上海第二工业大学图书馆',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/6f59c0f9-96d5-496a-b27d-5319f5169075.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/MubbEPefBn2IkLnNXBFOZg',
  ),
  SspuWechatAccount(
    name: '二工大图情快讯',
    wxAccount: '二工大图情快讯',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-02/3ad1db9861fa57161a369ac124edb430_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/C4hv5BzAjbBFT6KRzHAp0Q',
  ),
  SspuWechatAccount(
    name: 'VOEC SSPU',
    wxAccount: 'VOEC SSPU',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-01/fc7d0455d7791100fd7d4afce81f32d1_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/NAYJ0SsSeuuNtCWM3ictWw',
  ),
  SspuWechatAccount(
    name: '青春二工大',
    wxAccount: 'ssputw',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/0fee96e0-25fb-4c6d-b015-63becf1e07f6.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/-0zpln9QGo3IW7NtY3DnmA',
  ),
  SspuWechatAccount(
    name: '二工大党建',
    wxAccount: '二工大党建',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/81c110ec-4b91-4547-9058-c0473706322f.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Ezq3sDYC35hvwKYo2qY0Hw',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学学报',
    wxAccount: '上海第二工业大学学报',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/23-12/441d9f94ea756dc7985a9399a3d798aa_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Egson4ObsF-QrESOGGQ5Ww',
  ),
  SspuWechatAccount(
    name: '金海护航',
    wxAccount: '金海护航',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/23-06/c2707711da8ceaae004e91db464c5485_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/MW1eEY7GEGPWpr4RnEZdfw',
  ),
  SspuWechatAccount(
    name: '上工大学工',
    wxAccount: '上工大学工',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/26-04/0d667cea18c7febea1879d7ba569e1dc_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/5olyen-YmR3NVvVofXTIzQ',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学研究生教育',
    wxAccount: 'Sspu_yjs',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-03/4dc6a38647759d75cd3e47aa179b709a_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/V93DrIwvGkoUE1bkaRM-Bw',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学学生事务中心',
    wxAccount: '上工大学生发展与事务中心',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/074136d7-9caa-4d43-954b-abede838e384.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/sOIz3DvyCn-kMds2B3cDbg',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学招生办',
    wxAccount: '上海第二工业大学招生办',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-01/3371353b22c6cac35447a1df8d0fab19_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Twlkb10_he8zldwtGeUX_A',
  ),
  SspuWechatAccount(
    name: '二工大教务E线',
    wxAccount: '二工大教务E线',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-09/44010395c5ddb284ead132e82e3d8868_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/iaoT2yRhfUf7i_pHShvB1A',
  ),
  SspuWechatAccount(
    name: '二工大心理健康教育与咨询中心',
    wxAccount: 'SSPUmentalhealth',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-09/05d2455274d84451fc8111f3f9c39512_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/Xqc-0lBaQFInODmVjxiSuQ',
  ),
  SspuWechatAccount(
    name: '二工大金海职场',
    wxAccount: '二工大金海职场',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-03/c6dad2c169989defdaa336a17ff56567_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/8CXrlQAkFrp6J67zAbCa7w',
  ),
  SspuWechatAccount(
    name: '校园单车志愿服务队',
    wxAccount: '校园单车志愿服务队',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-11/1131e92f0f1b96fad94a2388e5a1db8f_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/J93XL-T_WCQBcsk9SXf0NA',
  ),
  SspuWechatAccount(
    name: '上海第二工业大学校友会',
    wxAccount: '上海第二工业大学校友会',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-03/8faa7d196a3d0ab2ab91013a1cb34376_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/hhIeZAa1M35ygASKo2s8mQ',
  ),
  SspuWechatAccount(
    name: '二工大学工在线',
    wxAccount: '二工大学工在线',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/22-04/6eef443c535fd6bdbfa10062caae772e_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/BWAZosKufIpRxL1uKKuTRw',
  ),
  SspuWechatAccount(
    name: '二工大离退休',
    wxAccount: '二工大离退休',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-01/ca05a868ac5c4a6c6683e1835da1397c_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/3S6_D72slWgisCxMG29_QA',
  ),
  SspuWechatAccount(
    name: '辅导员说',
    wxAccount: 'Sspufdys',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/24-03/8269af08b24010026d40dd5b8cb9b04a_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/YExmfdShktpc04o4n5JcPA',
  ),
  SspuWechatAccount(
    name: '天使馨语',
    wxAccount: '天使馨语',
    iconUrl: 'https://st-img.yunban.cn/uploads2/weixin/newMedia/21-09/3dff78201cfa11a41ef0168310e47888_small.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/UDchGA8Egwe37ZsTh0r42A',
  ),
  SspuWechatAccount(
    name: '博恩公关',
    wxAccount: 'sspupra',
    iconUrl: 'http://weixin.campusplus.com/uploads/images/tqeditor/3693483f-41ba-4e87-b6d5-d752a230324f.jpg',
    articleUrl: 'https://mp.weixin.qq.com/s/s6a0uAhBfYqXkH6Qt3PhfA',
  ),
];
