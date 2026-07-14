# 七段数码管跑马灯实验

## 文件

| 文件 | 说明 |
|------|------|
| `marquee.v` | 顶层设计（上板用） |
| `marquee_tb.v` | 仿真测试 |
| `icf.xdc` | 引脚约束 |

## 功能

1. **八位七段动态扫描**：100MHz 分频后轮流点亮 8 位数码管
2. **数码管跑马灯**：`0~F` 字符在 8 位窗口中循环滚动
3. **LED 跑马灯**：16 个 LED 单点追逐

## 开关控制

| 开关 | 作用 |
|------|------|
| `sw_i[0]=0` | 数码管向左滚 |
| `sw_i[0]=1` | 数码管向右滚 |
| `sw_i[1]=0` | LED 向左跑 |
| `sw_i[1]=1` | LED 向右跑 |
| `sw_i[2]=1` | 暂停滚动 |

## Vivado 流程（学校电脑）

1. Create Project → RTL Project
2. 芯片选 **xc7a100tcsg324-1**
3. Add Sources → 只加 `marquee.v`（Design Sources）
4. Add Constraints → 加 `icf.xdc`
5. Sources 中确认顶层为 **`marquee`**（右键 Set as Top）
6. Run Synthesis → Run Implementation → Generate Bitstream
7. Open Hardware Manager → Auto Connect → Program Device

## 上板现象

- 数码管 8 位不断滚动显示 `01234567` → `12345678` → … → `F0123456` …
- LED 有一个灯点从一端跑到另一端
- 拨 `SW0/SW1` 改方向，拨 `SW2` 暂停

## 注意

- 不要把 `marquee_tb.v` 设为顶层
- 顶层模块名必须是 `marquee`，与文件一致
- 断电后 FPGA 配置丢失，需重新烧录
