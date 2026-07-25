# EDOG Application（HarmonyOS）

EDOG 智能四足机器人 **手机端 App**（OpenHarmony / HarmonyOS NEXT 工程）。

狗端硬件：**软通动力通晓开发板（RK2206）**。

主仓库：[Edog_powered_by_rk2206](https://github.com/yangzhiyong3508/Edog_powered_by_rk2206)

## 功能概览

- **控制页**：视频预览（连深度学习转发 `8766`）、九宫格遥控、跟随开关、语音面板（唤醒词/语速/音量）
- **陪伴页**：学我说话 / 陪我聊天、互动动作（喂食/逗它/夸奖/复原）
- **运动调参**：前后俯仰（机身高度差）、步长/步高、速度等级
- **舵机校准**：12DOF 分通道物理中位角
- **事件提醒**、聊天记录、账号设置

## 目录结构

```
Application/
├── AppScope/                 # 应用级配置与资源
├── entry/
│   └── src/main/
│       ├── ets/
│       │   ├── pages/        # Control / Conversation / ServoAdjust / MotionTuning ...
│       │   ├── components/
│       │   ├── utils/        # HTTP、图传 WS、调参、校准等
│       │   └── theme/
│       └── resources/
├── hvigor/
├── build-profile.json5
└── oh-package.json5
```

## 开发环境

- DevEco Studio（与工程 API 版本匹配）
- HarmonyOS SDK / ohpm
- 可访问后端：默认 `localhost` 配置为云服务器 IP（可在 App 内改）

## 构建与运行

1. 用 DevEco 打开本仓库根目录  
2. 同步依赖（ohpm）  
3. 连接真机/模拟器，Run `entry`  

```bash
# 命令行示例（需本机已配置 hvigor）
hvigorw assembleHap
```

## 与后端约定

| 能力 | 接口 |
|------|------|
| 遥控 | `POST /action` `{ "command", "stepLengthMm?", "stepHeightMm?" }` |
| 跟随开关 | `GET/POST /tracker/status` |
| 语音设置 | `/api/accounts/updateVoice`、`updateWakeWord` |
| 调参 | `/api/dog-debug/config`、`runtime-tuning` |
| 舵机 | `/api/dog-debug/*` |
| 图传 | `ws://{deeplearning_ip}:8766` |

## 安全

- 不要提交 Coze Token、华为 IAM 密码等  
- `CozeUtil` 中 token 请改为本地配置或由后端代理  
- 见根目录 `.gitignore`

## 相关仓库

- 后端：[SpringBoot](https://github.com/yangzhiyong3508/SpringBoot)  
- 视觉：[DeepLearning](https://github.com/yangzhiyong3508/DeepLearning)  
- 图传：[ESP32](https://github.com/yangzhiyong3508/ESP32)  
- 狗端固件：[edog_project_docker](https://github.com/yangzhiyong3508/edog_project_docker)  
