import Foundation

struct GamePrompt: Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
}
struct DiscoveryGame: Identifiable {
    let id: String
    let number: String
    let title: String
    let subtitle: String
    let icon: String
    let prompts: [GamePrompt]
    let reflectionPrompt: String
    static func title(for id: String) -> String { all.first { $0.id == id }?.title ?? L("自我探索") }
    static var values: [String] { [L("自由"), L("安全感"), L("成就"), L("亲密关系"), L("独立"), L("归属感"), L("创造力"), L("公平")] }
    static var all: [DiscoveryGame] { [
        .init(id: "values", number: "01", title: L("价值观排序"), subtitle: L("什么对你更重要？"), icon: "slider.horizontal.3", prompts: [], reflectionPrompt: L("最近哪一次选择，体现了排在最前面的价值？")),
        .init(id: "scenarios", number: "02", title: L("情境选择"), subtitle: L("看见你的第一反应"), icon: "arrow.triangle.branch", prompts: [
            .init(question: L("认真准备的方案被否定时，你更可能怎么做？"), options: [L("先问清对方的理由"), L("给自己一点时间消化"), L("解释自己的考虑"), L("重新寻找其他方案")]),
            .init(question: L("朋友临时改变了约定，你首先会关注什么？"), options: [L("是不是发生了什么事"), L("自己的安排被打乱了"), L("如何重新安排时间"), L("这是不是经常发生")]),
            .init(question: L("当一次讨论出现分歧，你更想先做什么？"), options: [L("确认共同的目标"), L("把自己的想法说完整"), L("听听每个人的担心"), L("暂停，整理后再聊")])
        ], reflectionPrompt: L("这些选择像平时的你吗？有没有一次你做了不同的选择？")),
        .init(id: "emotions", number: "03", title: L("情绪识别"), subtitle: L("给感受一个名字"), icon: "water.waves", prompts: [
            .init(question: L("发出的重要消息迟迟没有回复，此刻你更接近哪种感受？"), options: [L("焦虑：担心结果"), L("失落：期待没有被回应"), L("平静：愿意等一等"), L("困惑：不清楚发生了什么")]),
            .init(question: L("有人记得你随口提起的小事，你更接近哪种感受？"), options: [L("温暖：被放在心上"), L("惊喜：超出了预期"), L("安心：关系是稳定的"), L("复杂：暂时说不清")]),
            .init(question: L("完成一个困难的任务后，你最明显的感受是什么？"), options: [L("自豪：认可自己的努力"), L("轻松：终于可以休息"), L("期待：想尝试下一步"), L("疲惫：需要恢复精力")])
        ], reflectionPrompt: L("哪一个情绪词让你觉得更准确？它通常出现在哪种情境？")),
        .init(id: "boundaries", number: "04", title: L("边界感探索"), subtitle: L("温和，也可以坚定"), icon: "circle.lefthalf.filled", prompts: [
            .init(question: L("休息日，同事请你处理一件并不紧急的事。你的界限在哪里？"), options: [L("愿意帮忙，但约定时间"), L("工作日再处理"), L("先确认是否真的紧急"), L("这次可以，下次提前沟通")]),
            .init(question: L("朋友希望知道你不想分享的私人细节，你会如何回应？"), options: [L("直接说暂时不想聊"), L("只分享自己愿意说的部分"), L("解释为何需要隐私"), L("提出换一个话题")]),
            .init(question: L("你已经很累，家人希望你参加聚会。你更愿意怎么做？"), options: [L("表达需要休息"), L("短暂参加再离开"), L("商量换个时间见面"), L("先了解这次聚会的重要性")])
        ], reflectionPrompt: L("哪一条边界最值得被你认真对待？试着写一句可以说出口的话。")),
        .init(id: "thinking", number: "05", title: L("认知偏好"), subtitle: L("探索理解世界的方式"), icon: "square.stack.3d.up", prompts: [
            .init(question: L("面对一个陌生的任务，你通常从哪里开始？"), options: [L("先看整体目标"), L("找一个具体案例"), L("拆成可以做的小步骤"), L("和有经验的人聊聊")]),
            .init(question: L("两个人对同一件事说法不同，你首先会怎样？"), options: [L("寻找可以核实的事实"), L("了解各自的处境"), L("暂时保留多种可能"), L("回顾自己亲眼看到的部分")]),
            .init(question: L("一个选择没有明显的最优解，你更依赖什么？"), options: [L("与自身价值是否一致"), L("现有信息和实际代价"), L("直觉与过往经验"), L("先尝试一个可调整的方案")])
        ], reflectionPrompt: L("你常用的思考方式在哪些时候有帮助？在哪些时候想换一种？")),
        .init(id: "strengths", number: "06", title: L("优势发现"), subtitle: L("从做成的事里找线索"), icon: "sparkles", prompts: [
            .init(question: L("回想一件你做成的小事，你觉得自己贡献最多的是什么？"), options: [L("把复杂问题理清楚"), L("让大家愿意一起行动"), L("坚持把细节做到位"), L("提出一个新的可能")]),
            .init(question: L("别人遇到困难时，通常因为什么找你？"), options: [L("愿意认真听他们说"), L("可以给出清晰的建议"), L("能把事情实际推进"), L("会看到不同的角度")]),
            .init(question: L("哪一种过程最容易让你投入？"), options: [L("创造一个以前没有的东西"), L("理解一个复杂的问题"), L("帮助一个人发生改变"), L("把想法一步步变成现实")])
        ], reflectionPrompt: L("写下一次真实经历：你做了什么，带来了什么变化？"))
    ] }
}
