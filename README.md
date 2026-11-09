# PRISM · 像素宝石 / 切型与材质

[在线试玩](https://dsixy.github.io/prism-gems/) · [Windows 下载](https://github.com/Dsixy/prism-gems/releases/latest)

打开网页即可旋转、换色和观察宝石光学效果，无需安装 Godot。推荐桌面 Chrome、Edge 或 Firefox；首次打开会加载引擎与资源。网页版可按 **P** 下载当前宝石 PNG。


用 Blender 4.2.3 和 Godot 4.6.1 制作的桌面原型。包含九种常见刻面切型和三种圆润外形，支持旋转、换色、内部反射、近似色散和日光／暖灯切换。包含单色宝石、双色碧玺、紫黄晶色带、西瓜碧玺、变石、水晶欧泊、黑欧泊、珍珠、金绿猫眼和月光石。切型参考见 [docs/cut_reference.md](docs/cut_reference.md)，双色与变石见 [docs/materials_v2.md](docs/materials_v2.md)，欧泊见 [docs/opal_material.md](docs/opal_material.md)，珍珠、猫眼、月光石与圆润模型见 [docs/rounded_materials.md](docs/rounded_materials.md)。

完整的光学性质与扩展路线见 [特殊光学材质调研](docs/material_optics_research.md)。目前各类材质均已接入第一版实时近似。

## 运行

双击根目录的 `启动像素宝石.cmd`，或直接运行 `build/PRISM.exe`。Windows 版本已经内嵌项目资源，不需要安装 Godot；分发时请同时保留 `build/GODOT_LICENSES.txt`、`build/PBRT_LICENSE.txt` 和 `build/THIRD_PARTY_NOTICES.txt`。

用 Godot 打开 `project.godot`，按 F6/F5 运行主场景即可继续开发。项目使用 Compatibility / OpenGL 3.3 渲染器。

## 操作

| 操作 | 效果 |
| --- | --- |
| 鼠标左键拖动宝石 | 调整旋转角度，松开后恢复此前的自动旋转状态 |
| 滚轮 | 缩放 |
| 空格 / 暂停旋转按钮 | 开关自动旋转 |
| 左侧材质菜单 | 选择十类材质；启动默认展示细化后的粉色水滴形；也可切换 146 面椭圆形比较内部反射。菜单切入珍珠时推荐圆珠，切入猫眼／月光石时推荐椭圆弧面 |
| 珍珠的体色、光泽、粉绿晕彩 | 调整奶油色底体、抛光高光与柔和干涉色 |
| 猫眼的体色、眼线亮度、宽度、纤维方向 | 调整内含物产生的亮带；转动灯光可观察眼线滑动 |
| 月光石的体色、月光亮度、范围、浮光深度 | 调整内部宽光晕及其浮动深度，与外层白色高光分别呈现 |
| 月光石的彩虹晕彩 | 在蓝白月光与柔和彩虹浮光之间调整；默认 85%，光晕范围默认 78%。设为 0 后可观察蓝白配方 |
| 月光石／猫眼换成刻面后的“刻面火彩” | 调整真实内部折射路径的 RGB 色散；与“光效微调”的彩色火彩同步。设为 0 仍保留白色闪光及光晕／眼线 |
| 光效微调 → 刻面通透度 | 为刻面月光石／猫眼混合柔和底体与清透反射光路；光晕或眼线独立保留 |
| 欧泊的彩斑大小、变彩亮度、乳浊程度 | 水晶欧泊调整彩斑与通透雾感；黑欧泊调整深色底体上的大彩斑与彩层衰减。两种材质分别保存这三项设置 |
| 欧泊的灯光方向 | 固定宝石时单独转动摄影棚光源，观察不同彩斑亮起或变色 |
| 色带位置、交界柔和度、方向 | 调整体内分区；西瓜碧玺为径向包裹色，不需要方向参数 |
| 两侧颜色 | 自定义分区的两种颜色 |
| 日光 / 暖灯按钮，或 L | 切换日光 D65 与白炽灯 A；变石从蓝绿变为紫红 |
| 变石的颜色浓度 | 调整吸收，观察薄色与浓色的区别 |
| 1—6 / 颜色按钮 | 切换六种配色 |
| 自选颜色 | 任意颜色，地面光斑也会跟随变化 |
| 画面右上角外形菜单 / [ 与 ] | 切换九种刻面切型、圆珠、椭圆珠或椭圆弧面，保留当前材质、体色和光效参数 |
| T / 俯视按钮 | 在斜视与俯视之间切换，便于观察轮廓与切面排列 |
| R / 重置视角 | 恢复初始取景 |
| 展开“光效微调” | 调整内部闪光、彩色火彩、地面焦散、阴影柔和度和灯箱方向；内容超出窗口时左栏可滚动 |
| 地面焦散 / 阴影柔和度 | 前者调整折射光线落地强度，0 可单独观察阴影；后者柔化边缘。两者随宝石旋转、倾斜和灯光方向变化 |
| 十字星闪光 | 为透明刻面类材质开关附加星光；黑欧泊、珍珠、猫眼、月光石使用自身高光，该开关停用 |
| 192 / 256 / 320 px | 切换实际渲染分辨率，使用整数倍最近邻放大 |
| 保存当前宝石 PNG | 导出三倍放大的图像，并打开保存目录 |

图像保存到 Godot 的应用数据目录下 `captures` 文件夹。Windows 通常为 `%APPDATA%\Godot\app_userdata\PRISM · 像素宝石\captures`，界面会显示实际路径。

## 文件

- `assets/gem/brilliant.blend`：可编辑的 Blender 源文件。
- `assets/gem/brilliant.glb`：实际在 Godot 中渲染的模型，保留平面法线。
- `assets/gem/brilliant.json`：与模型配套的切面平面、顶点和切面中心。
- `assets/gem/cuts/`：其余八种刻面切型、三种圆润外形的 `.blend`、`.glb`、`.json` 及外形图标。
- `assets/gem/cut_catalog.json`：切型、模型、光学数据、图标与来源的对应目录。
- `scenes/gem_stage.tscn`：3D 场景、相机、地面和环境。
- `shaders/gem.gdshader`：光学着色器；内部计算最多十次反射交互，分别追踪三个色带的折射路径，并处理颜色吸收与色散。
- `shaders/floor.gdshader`：三维轮廓投影阴影、半影与环境遮蔽。
- `shaders/caustic_photons.gdshader`、`scripts/ground_optics.gd`：前向 RGB 光线穿过实际几何，在地面沉积折射能量；见 [地面光学说明](docs/ground_optics.md)。
- `scripts/main.gd`：桌面界面、输入和颜色预设。
- `assets/materials/`：线性浮点变石透射表、三维欧泊晶域参数和数据说明。
- `tools/build_alexandrite_lut.py`：从 CIE 光源／颜色匹配数据与近似吸收谱生成变石表。
- `tools/build_opal_domains.py`：生成固定随机种子的三维欧泊参数场；保存方向与间距，不保存彩虹贴图。
- `shaders/opal.gdshaderinc`：浅层体积采样、方向选择与衍射变彩近似。
- `shaders/soft_gems.gdshaderinc`：珍珠光泽／晕彩、猫眼定向反射、月光蓝白／彩虹浮光。
- `tools/build_smooth_forms.py`：重建圆珠、椭圆珠、平底椭圆弧面的 Blender 源文件与解析参数。
- `artifacts/interface.png`：实际运行截图。
- `artifacts/qa_report.json`、`artifacts/image_checks.json`：功能与图像验证结果。
- `artifacts/cut_catalog.png`、`artifacts/cut_checks.json`：12 种外形的真实俯视渲染和 72 种外形／颜色组合检查。
- `artifacts/material_comparison.png`：同视角的日光／暖灯实际渲染对比。
- `artifacts/material_checks.json`：96 个分区／变石、照明、外形组合及变石颜色响应检查。
- `artifacts/interface_opal.png`、`artifacts/opal_rotation.gif`：欧泊界面与 72 帧实际旋转预览。
- `artifacts/opal_comparison.png`、`artifacts/opal_checks.json`：角度、灯光、乳浊程度对比及 24 个欧泊／外形／照明组合检查。
- `artifacts/soft_gems_lighting.gif`、`artifacts/soft_gems_comparison.png`：珍珠、猫眼和月光石的实际渲染动图与静帧。
- `artifacts/soft_gems_checks.json`：三种新材质 × 12 外形 × 两种照明的 72 个组合，以及眼线／浮光位移与参数验证。
- `artifacts/moonfire_before_after.png`、`artifacts/moonfire_rotation.gif`：月光石修正前后，以及光晕／火彩分别开关的实际画面对比。
- `artifacts/facet_effect_checks.json`：月光石与猫眼 × 12 外形 × 两种照明的 48 组火彩开关对照，验证光晕、色散、反射深度与通透度独立生效。
- `artifacts/refinement_comparison.png`、`artifacts/black_opal_rotation.gif`：普通宝石灯光与吸收调整前后，以及黑欧泊的实际旋转画面。
- `artifacts/refinement_checks.json`：六种配色的明暗层次、24 个黑欧泊组合、彩斑连贯性、独立灯光响应及静态稳定性检查。
- `artifacts/moonrainbow_before_after.gif`、`artifacts/moonrainbow_comparison.png`：月光石优化前后的同角度转台，以及日光／暖灯、光晕／火彩独立开关的实际截图。
- `artifacts/moonrainbow_checks.json`：24 个月光石组合、彩虹带覆盖范围、暖绿冷色区连贯性、灯光响应、通透度、反射深度与控件验证。
- `artifacts/ground_rotation_lighting.gif`、`artifacts/ground_comparison.png`：旋转宝石／旋转灯光的真实画面及地面效果前后对比。
- `artifacts/ground_checks.json`：24 个外形／照明组合、10 种材质、折射率／色散响应、阴影柔化、静态稳定性和宝石像素隔离检查。

## 光学与像素流程

Blender 平面模型 → GLB + 法线/距离数据 → Godot 真实 3D 网格 → 在局部坐标中追踪内部光线 → 环境灯箱反射、颜色吸收、RGB 近似色散 → 低分辨率 SubViewport → 最近邻整数倍放大。

刻面模型使用闭合凸体。着色器从可见表面进入模型，在同一组平面中查找下一个出射面，并处理折射与全内反射。圆珠／椭圆珠使用解析椭球求交，椭圆弧面使用截去下半部、带平底的椭球求交，不受 192 个切面平面的限制。三个折射色带与玻璃类材质均支持这两类几何。

摄影棚由分隔灯箱、窄灯条和小点光源构成。配合轻微的透视，内部映像会随旋转产生细碎的亮暗和短暂闪光。普通单色及分区宝石收窄大灯箱、减少环境填充，单色配方适当增加吸收并略减闪光总强度，保留高光峰值和有色暗面。变石和已有特殊材质保留此前照明响应。地面已改用前向折射光线：每个 RGB 色带从上方摄影棚光源的 56×56 固定采样网格出发，穿过当前几何，处理折射、吸收、全内反射及首次透射落地，再用椭圆核累积成焦散。灯光、宝石姿态、切型、折射率、色散和体色均影响结果；阴影使用同一地面光源的三维轮廓投影与柔化边缘。

双色和色带固定在晶体局部坐标中，在每段内部光程上累积 Beer–Lambert 吸收；平直与条带分界采用解析积分，径向包裹色采用空间采样。变石将 CIE D65／A 光谱、CIE 1931 颜色匹配函数、近似铬吸收谱按光程积分，经过 Bradford 色适应后生成浮点透射表。每条反射路径按累计光程查表。吸收谱经过美术调整，并非真实样品的实测值；地面变石焦散使用对应光源的代表透射色做 RGB 光程吸收，未执行完整光谱查表。

水晶欧泊使用固定在物体内部的三维晶域参数场。前两段折射路径各取三个浅层样本，结合域的方向、间距、观察方向与两组摄影棚灯的方向计算变彩。彩斑随受光角度显隐，局部主色随角度变化；不使用时间驱动的彩虹循环。乳浊程度控制光程衰减和柔和散射，抛光层反射继续独立保留。当前为实时美术近似，继续使用现有刻面模型。

黑欧泊共用参数场，使用独立的最近邻采样保留大彩斑内部的方向与主色；另一个平滑边界场控制彩斑边缘的淡出，避免对不同方向插值造成一圈碎彩。两个浅层样本叠加在深色底体上，细纹理只调制明暗，小角度响应产生细闪，外层抛光高光独立计算。该配方采用不透明深色基体，不通过十次镜面反射重复大彩斑；原水晶欧泊的透明光路与参数数据保持原样。

珍珠使用不透明柔和底体、抛光高光和薄层干涉色近似；猫眼使用固定纤维方向与折射后的观察／照明响应，形成滑动亮带；月光石将浅层浮光与外部白色抛光反光分开计算，现可在蓝白月光与宽柔彩虹带之间调节。这些均为实时美术近似，不是实测材料模型。

月光石与猫眼在刻面外形上同时执行共用的三色带内部光路，并将材质光晕／眼线作为单独响应合成。光晕不会取代折射和色散；通透度控制柔和底体与清透光路的比例，月光的薄雾适当遮蔽明亮灯箱，避免蓝光被冲白。弧面版本保留柔和响应，珍珠保持不透明珠光。火彩滑块为美术强度，默认较克制，高值用于强化展示。

彩虹月光采用固定在物体内的连续层理坐标与折射后采样位置，宽而相互重叠的 RGB 响应构成柔和色带；光照／观察方向改变色带位置、覆盖与亮度。冠部的低频云状浮光在透射光路上叠加有界的彩色薄雾，保留其下的切面细节。此彩虹展示配方与 RGB 折射路径产生的火彩分别计算，不使用屏幕贴图或随时间循环的色相。

目前可选择圆形明亮式、椭圆、水滴、马眼、公主方形、祖母绿阶梯、阿斯切方阶梯、枕形、三角形、圆珠、椭圆珠和椭圆弧面。换型时同步更新光学几何、取景与地面轮廓，保留当前材质参数。原石切割和收藏柜仍属于后续阶段。

## 修改与重建模型

重新生成整套切型（会重建每种切型的 `.blend`、`.glb`、`.json`、图标与切型目录）：

```powershell
blender --background --factory-startup --python tools/build_cuts.py
blender --background --factory-startup --python tools/build_smooth_forms.py
```

手动编辑源 `.blend` 后，选中宝石，在 Blender 的 Scripting 工作区打开 `tools/export_current_gem.py` 并运行。也可以保存模型后从命令行导出：

```powershell
blender --background assets/gem/brilliant.blend --python tools/export_current_gem.py
```

导出脚本会根据所选对象的 `cut_id` 自定义属性更新对应模型，检查闭合性、凸性和平面性，将物体变换烘焙到副本，并同时更新 GLB 和 JSON。最大支持 192 个不同的切面平面和 32 条地面轮廓边。修改后重新聚焦 Godot，等待 GLB 导入；运行中的原型需要重启以读取新数据。

圆润模型的光学几何由椭球轴长、中心与平底定义；修改其尺寸请编辑 `tools/build_smooth_forms.py` 中的参数并重建。刻面导出脚本会拒绝导出这些解析模型，避免网格与求交形状不一致。重建九种刻面切型会保留目录中已有的圆润外形。

## 检查与打包

```powershell
$prismGodot = 'godot' # 或填写本机 Godot 4.6.1 可执行文件路径
& $prismGodot --headless --editor --path . --import
& $prismGodot --path . --audio-driver Dummy -- --qa-ground
& $prismGodot --path . --audio-driver Dummy -- --qa
python tools/check_images.py
python tools/check_cut_library.py
python tools/check_materials.py
& $prismGodot --path . --audio-driver Dummy -- --qa-opal
python tools/check_opal.py
& $prismGodot --path . --audio-driver Dummy -- --qa-soft
python tools/check_soft_gems.py
& $prismGodot --path . --audio-driver Dummy -- --qa-fire
python tools/check_facet_effects.py
& $prismGodot --path . --audio-driver Dummy -- --qa-refinement
python tools/check_refinement.py
& $prismGodot --path . --audio-driver Dummy -- --qa-moon
python tools/check_moonrainbow.py
python tools/check_ground.py
& $prismGodot --path . --audio-driver Dummy -- --qa-cut-detail
python tools/check_cut_detail.py
& $prismGodot --headless --path . --export-release 'Windows Desktop' build/PRISM.exe
```

渲染检查需要可用的显卡和窗口环境；`--headless` 的空渲染器无法验证画面。检查涵盖 12 个 GLB 与各自平面／解析数据的一致性、换型时参数保留、俯视与斜视、72 个单色组合、96 个分区／变石／照明／外形组合，以及原有旋转、像素放大、光斑、内部反射和火彩。

欧泊检查覆盖 24 个外形／照明组合与 72 个旋转角度；珍珠、猫眼、月光石检查另覆盖 72 个组合与 60 个照明角度。猫眼和月光石使用各灯光下关闭对应效果的参考图，单独验证眼线和蓝色光晕的移动，同时检查晕彩、光泽、眼线宽度／方向、浮光深度和静止画面的稳定性。

灯光／黑欧泊优化检查额外覆盖 24 个黑欧泊组合和 60 帧旋转。用相同配色和光学参数分别渲染新旧灯箱，检查浅白亮面的面积减少、有色暗面增加，同时保留高光峰值。将各灯光下关闭变彩的参考扣除后，仍需出现彩斑变化；水晶欧泊与黑欧泊的三项彩斑设置必须互不覆盖。水晶欧泊参数场哈希值保持一致；未修改外形的材质参考图在宝石轮廓内与回归结果逐像素一致；细化后的水滴／椭圆使用本轮几何前后对照，地面部分单独验证。

彩虹月光检查覆盖 12 外形 × 两种照明，分别关闭光晕或色散以隔离各项效果。默认光晕的可见面积及宽度应大于原蓝光，暖色、绿色、冷色区均应连贯；固定宝石改变灯光后，扣除无光晕参考仍需出现变化。还检查光晕范围、深度、通透度、多次反射和暂停后的逐像素稳定性。蓝白模式配合原范围 48% 可逐像素还原旧配方。

`--qa-fire` 另检查 48 组火彩 0／1 的对照。刻面上必须出现色散引起的颜色变化，弧面版本保持原有柔和表现；月光与火彩分别关闭时，另一项仍可见。检查还验证多次内部反射、通透度、控件同步及换型参数保留，关闭装饰性十字星。

`export_presets.cfg` 使用 Godot 4.6.1 官方导出模板。开发时先在 Godot 中安装对应版本的 Export Templates；Windows 和 Web 均可复现导出。

视觉参考：[像素宝石视频](https://www.bilibili.com/video/BV1ba4g6LEPz/?p=2)、[宝石小工坊试玩](https://www.bilibili.com/toy/CXkrG73gssvfBjim)。本项目的模型、脚本、着色器和界面均在本地重新实现。

地面专项先生成 12 种外形的独立白色几何掩码，再运行材质专项，避免地面变化干扰宝石像素检查。地面检查覆盖 24 个外形／照明组合和 10 种材质，单独扣除关闭焦散的参考，验证旋转、灯光、折射率和色散响应；同时检查阴影柔化、投影与静态稳定性。详见 [地面光学说明](docs/ground_optics.md)。

水滴形从 70 面细化为 136 面，椭圆形从 74 面细化为 146 面，冠部、亭部和腰部同步增加实际分面。可见光路与地面光路的容量均提高到 192 面。完整配方、局部亮点指标与重建命令见 [精细切面说明](docs/cut_refinement.md)；实际前后转台见 `artifacts/cutdetail_rotation.gif`，结果见 `artifacts/cutdetail_checks.json`。

## 网页导出与发布

项目包含单线程 Web 导出预设，使用 WebGL 2.0，不依赖自定义跨域隔离响应头，可部署到 GitHub Pages。中文字体为改名后的 Noto Sans SC 子集，网页保存按钮会直接下载 PNG。

```powershell
New-Item -ItemType Directory -Force build/web
godot --headless --editor --path . --import
godot --headless --path . --export-release Web build/web/index.html
python tools/prepare_web.py
python -m http.server 8765 --directory build/web
```

浏览器打开 `http://localhost:8765`。不要直接双击导出的 HTML 文件。推送 `main` 后，GitHub Actions 会使用固定的 Godot 4.6.1 构建并部署网页，工作流见 `.github/workflows/pages.yml`。页面不收集账号信息，也不依赖外部字体服务。第三方组件与字体许可见 [third_party](third_party/THIRD_PARTY_NOTICES.txt) 和 [字体许可](assets/fonts/OFL.txt)。
