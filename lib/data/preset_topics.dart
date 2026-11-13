/// 内置话题库（对应原应用「话题库：话术卡片，一键复制」）
///
/// 纯静态数据，无网络依赖。每张卡片 = 一条可直接发送的话术。
class TopicCard {
  final String text;
  final String scene;
  const TopicCard(this.scene, this.text);
}

class TopicCategory {
  final String name;
  final String emoji;
  final List<TopicCard> cards;
  const TopicCategory(this.name, this.emoji, this.cards);
}

const presetTopics = <TopicCategory>[
  TopicCategory('破冰开场', '🧊', [
    TopicCard('破冰开场', '刚看到你朋友圈那张照片，拍摄地是哪？看起来蛮特别的'),
    TopicCard('破冰开场', '今天的天气莫名想找人聊天，结果就翻到你了'),
    TopicCard('破冰开场', '你资料里写的那个爱好，认真的还是随口填的？'),
    TopicCard('破冰开场', '忙什么呢？突然想起来好久没跟你说话了'),
    TopicCard('破冰开场', '最近在追什么剧/玩什么游戏？求个推荐'),
    TopicCard('破冰开场', '问个事，你上次说的那家店叫什么来着？'),
    TopicCard('破冰开场', '刚下班，你那边今天过得怎么样'),
    TopicCard('破冰开场', '有个事想听听你的看法，方便吗'),
  ]),
  TopicCategory('暧昧升温', '🔥', [
    TopicCard('暧昧升温', '跟你聊天的时候时间过得特别快，你有没有这种感觉'),
    TopicCard('暧昧升温', '今天路过一家店，第一反应是「她应该会喜欢」'),
    TopicCard('暧昧升温', '你笑起来的样子，我到现在还记得'),
    TopicCard('暧昧升温', '别人的消息我可能懒得回，你的我都是秒回'),
    TopicCard('暧昧升温', '周末有空吗？发现一家想拉你一起去的地方'),
    TopicCard('暧昧升温', '刚在看月亮，突然就想到你了，你说奇怪不奇怪'),
    TopicCard('暧昧升温', '如果我说我有点想你，你会不会觉得太快了'),
    TopicCard('暧昧升温', '你说话的声音，比我单曲循环的歌还上头'),
  ]),
  TopicCategory('约会邀请', '🌙', [
    TopicCard('约会邀请', '这周六下午有个市集，人不多东西好逛，一起去？'),
    TopicCard('约会邀请', '发现一家评价很好的店，两个人去才不会浪费'),
    TopicCard('约会邀请', '新上映那部片子口碑不错，挑个时间一起看？'),
    TopicCard('约会邀请', '附近新开了家咖啡馆，听说拍照好看，你去过没？'),
    TopicCard('约会邀请', '天气这两天特别好，适合出去走走，你来定时间'),
    TopicCard('约会邀请', '我查了下路线，周日天气也合适，要不就把计划定了？'),
    TopicCard('约会邀请', '你上次说想去的地方，我做了下攻略，发你看看？'),
    TopicCard('约会邀请', '别犹豫了，就当陪我散个步，好嘛'),
  ]),
  TopicCategory('道歉挽回', '🤝', [
    TopicCard('道歉挽回', '这件事是我考虑不周，让你难堪了，对不起'),
    TopicCard('道歉挽回', '我认真想过了，错在我没有站在你的角度想'),
    TopicCard('道歉挽回', '不需要你现在原谅我，但我想让你知道我意识到错了'),
    TopicCard('道歉挽回', '我知道一句对不起不够，之后我会用行动补上'),
    TopicCard('道歉挽回', '你生气是应该的，换我我也会生气'),
    TopicCard('道歉挽回', '冷静了两天，还是想跟你好好聊聊，可以吗'),
    TopicCard('道歉挽回', '这次是我不好，但请别把我直接划走，给我一次解释的机会'),
    TopicCard('道歉挽回', '我在意的从来不是争对错，是怕失去你'),
  ]),
  TopicCategory('职场沟通', '💼', [
    TopicCard('职场沟通', '收到，这部分我今晚整理好，明早发你确认'),
    TopicCard('职场沟通', '感谢提醒，这个点我确实疏忽了，马上调整'),
    TopicCard('职场沟通', '这个方案我有个补充建议，您看是否可行'),
    TopicCard('职场沟通', '辛苦您帮忙过一下，有问题我随时改'),
    TopicCard('职场沟通', '关于排期，想跟您同步下目前的进度和风险'),
    TopicCard('职场沟通', '这周时间实在排不开，您看下周三之前交可以吗'),
    TopicCard('职场沟通', '这块我不是特别熟，想请教您十分钟，方便吗'),
    TopicCard('职场沟通', '已经处理好了，附带把后续两步也做了，您过目'),
  ]),
  TopicCategory('日常关怀', '🍵', [
    TopicCard('日常关怀', '天气预报说明天降温，记得加件外套'),
    TopicCard('日常关怀', '看你昨天熬夜了，今天早点休息'),
    TopicCard('日常关怀', '忙归忙，饭要按时吃'),
    TopicCard('日常关怀', '到家了吗？到家说一声'),
    TopicCard('日常关怀', '你上次说胃不舒服，这几天好点没'),
    TopicCard('日常关怀', '累了就歇歇，事情永远做不完，身体是自己的'),
    TopicCard('日常关怀', '这周压力大吗？需要人陪聊随时找我'),
    TopicCard('日常关怀', '刚买了点水果，明天给你带过去'),
  ]),
];
