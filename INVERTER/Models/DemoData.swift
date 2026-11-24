import Foundation

/// Examples are never written into the user's private records.
enum DemoData {
    private static let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
    static var lin: Person { Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: L("林予"), group: .friend, note: L("可以自在分享日常的朋友"), createdAt: createdAt, isDemo: true) }
    static var chen: Person { Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: L("陈可"), group: .colleague, note: L("一起推进设计项目"), createdAt: createdAt, isDemo: true) }
    static var mom: Person { Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, name: L("妈妈"), group: .family, note: L("想多听听她最近的生活"), createdAt: createdAt, isDemo: true) }
    static var zhou: Person { Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, name: L("周宁"), group: .partner, note: L("一起探索生活的可能"), createdAt: createdAt, isDemo: true) }
    static var xu: Person { Person(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, name: L("许一"), group: .collaborator, createdAt: createdAt, isDemo: true) }
    static var people: [Person] {
        let names = [L("沈乔"), L("顾言"), L("苏禾"), L("陆遥"), L("叶知"), L("程安"), L("季然"), L("温宁"), L("许星"), L("唐乐"), L("陈溪"), L("宋闻"), L("夏树"), L("方圆"), L("林舟"), L("白露"), L("江临"), L("孟青"), L("李岸"), L("周月"), L("乔木"), L("安然"), L("沈澄")]
        let extra = names.enumerated().map { index, name in
            Person(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index + 6))!, name: name, group: RelationGroup.allCases[index % RelationGroup.allCases.count], createdAt: createdAt, isDemo: true)
        }
        return ([lin, chen, mom, zhou, xu] + extra).enumerated().map { index, original in
            var person = original
            person.closeness = index % 7 == 6 ? nil : ConnectionCloseness(rawValue: index % 5)
            person.birthday = PersonBirthday(month: index % 12 + 1, day: index % 25 + 1)
            person.likes = [L("散步、手冲咖啡、独立书店"), L("旅行、电影、安静的周末"), L("做饭、植物、和朋友聊天")][index % 3]
            person.dislikes = [L("临时改变约定"), L("太吵的环境"), L("被打断或被催促")][index % 3]
            person.careNotes = L("重要的安排提前沟通，给彼此留一点准备的时间。")
            return person
        }
    }
    static var events: [LifeEvent] {
        let entries: [(String, String, Emotion, String, String, UUID)] = [
            (L("把想法说出来之后"), L("项目讨论时，我提出先确认彼此的分工，陈可同意了。"), .calm, L("提前沟通让我更安心。"), L("清晰的沟通"), chen.id),
            (L("一次没有被打断的聊天"), L("和林予散步时，我说起最近的压力，她一直听我讲完。"), .happy, L("被认真听见的时候，我更愿意分享。"), L("被理解与倾听"), lin.id),
            (L("给忙碌按下暂停"), L("今晚和周宁商量，把周末的一项安排推迟了。"), .hopeful, L("表达自己的精力状况是有帮助的。"), L("清晰的沟通"), zhou.id),
            (L("电话里的小小牵挂"), L("妈妈打来电话，我因为赶工作匆匆结束了聊天。"), .tired, L("我想关心她，但当时的精力不够。"), L("属于自己的空间"), mom.id),
            (L("重新确认合作的节奏"), L("我和许一确认了交付时间，并说出了需要的支持。"), .calm, L("把期待说清楚，合作更容易推进。"), L("清晰的沟通"), xu.id)
        ]
        return entries.enumerated().map { index, entry in
            LifeEvent(id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index + 1))!, date: Calendar.current.date(byAdding: .day, value: -index, to: Date())!, title: entry.0, facts: entry.1, feeling: entry.2, interpretation: entry.3, need: entry.4, nextStep: L("下一次沟通前，先想清楚自己的期待。"), personIDs: [entry.5], isDemo: true)
        }
    }
}
