# Relationship Sphere · 3D 工程升级

当前 Connections 包含原生关系球、丰富人物档案、系统联系人选择导入和用户手动标注的亲密程度。下文保留三维交互的实现约定，最新人物功能见文末。

## 场景与数据

使用 RealityKit `ARView(cameraMode: .nonAR)` 和 `PerspectiveCamera`，不启动 ARSession，不使用摄像头，不请求相机权限，也没有引入 SceneKit 或第三方引擎。

```text
Anchor (0, 0, 0)
├── PerspectiveCamera：始终看向原点，pinch 改变观察距离
├── DirectionalLight
├── UserCore：独立 ModelEntity，球心固定为 (0, 0, 0)
└── SphereRotationRoot：simd_quatf 旋转
    ├── LatitudeLongitudeShell：9 个纬圈 + 12 个经圈组成的单一管状网格
    ├── Person ModelEntity × N：球面坐标上的真实球形 Mesh
    └── Center-edge ModelEntity × N：真实三维细线几何体
```

所有人物与中心的距离为一个场景单位。首次布局采用 Fibonacci Sphere；顺序按 UUID 确定。坐标存为 `Person.spherePosition`，旧 JSON 无此字段仍能读取。新增人物在固定候选球面上寻找与已有点距离最大的空位，保留全部已有坐标；删除、筛选与重新打开不会重排。

场景快照复用 Person、LifeEvent、Relationship：ID、名字、首字缩写、分类、相关事件数来自原有数据。Relationship 的中心边 ID 保留在实体名称中；暂不绘制人物之间的边，不推断关系强弱。示例仍明确标记，使用独立的固定示例朝向，不写入个人位置字段。

## 交互

- 横拖绕 Y 轴，竖拖绕 X 轴，组合后归一化为 quaternion。变化发生在 RealityKit 根 Entity 上，不是重排屏幕坐标。
- 松手按预测速度产生惯性，限制最大角速度，并以指数阻尼衰减至停止。
- pinch 调整透视摄像机距离。缩放限制为 0.76–1.12；最近观察距离通过视口宽高比和包围球计算，保留节点边界。
- 双击及复位按钮以 quaternion slerp 平滑恢复默认朝向与缩放，保留筛选。
- 可主动开启低速缓转（0.065 rad/s），默认关闭；拖动、缩放或点击后暂停，需要主动再次开启。
- 球区内的纵向拖动用于旋转，球区外仍可滚动页面。选中人物的摘要浮在球区底部，直接进入原有详情页；空白点击取消选择。
- 分类筛选控制真实 Entity 和对应边的可见性，并做短暂淡入淡出。开始隐藏时立即禁用碰撞，不会点到已过滤人物。

## 深度、标签与点击

- 人物球、中心球、连接线由 RealityKit 深度缓冲渲染；近侧人物可以自然遮挡远侧物体。
- 距离带来真实透视尺寸差异，材质及标签根据世界空间 Z 深度减淡。
- 文本使用 `ARView.project` 对真实节点世界坐标投影，UIKit overlay 仅承载始终朝向屏幕的文字和细描边。没有用平面图假装 3D。
- 标签优先选中节点和前景节点。先尝试节点下方，再尝试上方；与中心、其他节点或标签冲突时隐藏名称。50 人时有意保留稀疏标签；完整人物列表仍可访问。
- 普通点击通过 RealityKit `hitTest(..., query: .nearest)` 碰撞射线识别真实 Entity，再映射到 Person UUID。VoiceOver 激活使用同一选择入口。
- 核心不参与网络旋转。前景物体经过球心视线时遵守真实遮挡，核心位置与相机朝向不变。

## 生命周期与性能

- 共用人物 Mesh、连接线 Mesh 和预生成材质等级。
- 经纬辅助结构合并为一个 Mesh；不在逐帧更新中创建 Entity。
- CADisplayLink 只在惯性、复位、过滤动画、布局预热或主动缓转时运行；静止后停止应用侧逐帧回调。
- 切 Tab、详情跳转、后台状态会停惯性与缓转、隐藏渲染视图并停用场景锚点。
- UIViewRepresentable dismantle 时移除场景锚点、实体引用与选择回调；display-link target 通过 weak proxy 避免循环引用。
- 系统「减少动态效果」开启时不启用自动旋转或惯性，复位和筛选直接完成。

## 文件

| 文件 | 职责 |
| --- | --- |
| `Features/ConnectionsView.swift` | 保留页面框架，接入筛选、选择摘要与原详情路由 |
| `Models/Domain.swift` | 仅新增 Person 可选球面坐标 |
| `RelationshipSphereModel.swift` | Fibonacci / 增量布局、位置迁移、真实数据快照、旋转与缩放数学 |
| `RelationshipGeometry.swift` | 球面参考网格、材质、人物和中心边实体 |
| `RelationshipSceneController.swift` | RealityKit 层级、摄像机、碰撞选择、帧调度与生命周期 |
| `RelationshipLabelOverlay.swift` | 三维投影标签、深度排序、避让与可访问性节点 |
| `RelationshipSphereView.swift` | SwiftUI 手势桥接、UIViewRepresentable、场景容器 |
| `RelationshipSphereTests.swift` | 几何、稳定性、旧数据兼容、惯性与缩放边界测试 |
| `RelationshipSphereUITests.swift` | 真实模拟器手势、筛选、导航、密度、删除与生命周期测试 |

## 已知范围与下一步

支持导入或选择头像；没有头像时使用首字缩写。人物间的额外关系边、手工调整布局和云同步不属于本次范围。密集场景会隐藏冲突的文字；可通过旋转、筛选或下方列表查看人物。

模拟器验证不能替代真机 GPU 帧率、发热与能耗测量。下一步优先在实际 iPhone 上用 Instruments 检查 50 人持续交互，再决定是否继续优化材质更新或绘制批次。iOS 17 保留普通 UnlitMaterial 回退，iOS 18 及以上关闭额外色调映射以保持浅色设计。

## Apple 技术参考

- [非 AR 场景与 PerspectiveCamera](https://developer.apple.com/documentation/realitykit/perspectivecamera)
- [ARView 的投影、碰撞查询与场景控制](https://developer.apple.com/documentation/realitykit/arview)
- [UnlitMaterial 透明混合](https://developer.apple.com/documentation/realitykit/unlitmaterial/blending-swift.property)


## 2026-11-17 回归验收

五项关系球 UI 测试及六项空间／运动单元测试全部通过，包括筛选中旋转、空白取消选中、原档案复用、后台暂停、删除连线、规模 0／1／20／50、旋转／惯性／缩放／双击复位。已将材质及屏幕标签更新为动态黑白灰，并在中英切换和深色模式下检查实际截图。人物示例的 createdAt 固定，避免语言刷新时产生无意义的实体重建。

## 2026-11-18 · 人物资料与亲密程度

`Person` 新增可选 birthday、likes、dislikes、careNotes、organization、avatarData、contactIdentifier、closeness，旧档案无需清空。生日使用 Gregorian 月／日及可选年份，支持无年份的 2 月 29 日，校验不存在的日期；常见西方星座只作展示。编辑保存、导入批次均在写入失败时回滚。

`RelationGroup.uncategorized` 为未分类；系统联系人默认归入这里，不把未知关系当成好友或疏远。亲密程度五档由用户自行设置，与分类独立；未设置为灰色，较淡为冰蓝，亲密为鲜暖粉。颜色应用在真实三维中心边和头像边缘；位置依然不编码亲疏。示例扩至 28 个，示例资料和亲密程度明确为虚构数据。

`CNContactPickerViewController` 提供一次性的多选授权，不申请整本通讯录读取权限，不建立后台同步。选择后预览并确认，仅存姓名、生日、组织、缩小至 320×320 的 JPEG 头像和本地去重用 contact identifier。相同标识重复导入跳过；不会按姓名合并，也不会覆盖现有资料。电话、邮箱、通讯录备注和地址不保留，不写回系统联系人。照片也可经 PhotosPicker 单独选择。资料只保存在受保护的本机 JSON，可随全档案导出或清除，不自动传给模型。

图像在节点更新时解码缓存，逐帧只投影和布局。球壳仍只有一个 Mesh；新节点寻找空位时缓存候选点最近距离，批量导入保留旧坐标并降低重复计算成本。文字密集时继续避让，完整列表可访问。

Apple 行为依据：[联系人选择器](https://developer.apple.com/documentation/contactsui/cncontactpickerviewcontroller)、[联系人一次性访问说明](https://developer.apple.com/videos/play/wwdc2024/10121/)。
