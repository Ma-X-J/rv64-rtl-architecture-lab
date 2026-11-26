#!/usr/bin/env python3
"""Generate the README-level architecture diagram for the pipelined CPU.

The drawing is intentionally architectural rather than a gate-level
schematic.  It follows the module boundaries and control relationships in
rtl/PIPELINED_CPU.v while omitting individual muxes, comparators, and bit
slices that make an automatically elaborated schematic difficult to read.
"""

from __future__ import annotations

from html import escape
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs" / "architecture" / "pipelined-cpu-architecture.svg"

WIDTH = 1920
HEIGHT = 1200

COLORS = {
    "ink": "#16324F",
    "muted": "#58728A",
    "panel": "#F7FAFC",
    "line": "#CBD8E6",
    "data": "#1677C8",
    "control": "#E58A17",
    "feedback": "#7158C8",
    "trap": "#D94A4A",
    "memory": "#1C9A78",
    "if_fill": "#EAF5FF",
    "id_fill": "#EDF9F2",
    "ex_fill": "#FFF5E7",
    "mem_fill": "#F2EEFF",
    "wb_fill": "#FFF0F1",
    "reg_fill": "#E8EEF5",
    "cache_fill": "#E9F8F3",
    "system_fill": "#FFF2E7",
}


def attrs(**values: object) -> str:
    rendered = []
    for key, value in values.items():
        if value is None:
            continue
        rendered.append(f'{key.replace("_", "-")}="{escape(str(value), quote=True)}"')
    return " ".join(rendered)


def add(parts: list[str], tag: str, content: str = "", **values: object) -> None:
    attribute_text = attrs(**values)
    if content:
        parts.append(f"<{tag} {attribute_text}>{content}</{tag}>")
    else:
        parts.append(f"<{tag} {attribute_text}/>")


def rect(
    parts: list[str],
    x: float,
    y: float,
    width: float,
    height: float,
    fill: str,
    stroke: str = COLORS["line"],
    stroke_width: float = 2,
    radius: float = 14,
    css_class: str | None = None,
    dash: str | None = None,
) -> None:
    add(
        parts,
        "rect",
        x=x,
        y=y,
        width=width,
        height=height,
        rx=radius,
        fill=fill,
        stroke=stroke,
        stroke_width=stroke_width,
        stroke_dasharray=dash,
        filter="url(#soft-shadow)" if css_class == "block" else None,
        **({"class": css_class} if css_class else {}),
    )


def text(
    parts: list[str],
    x: float,
    y: float,
    value: str,
    size: int = 18,
    weight: int = 500,
    color: str = COLORS["ink"],
    anchor: str = "middle",
    family: str | None = None,
    opacity: float | None = None,
) -> None:
    add(
        parts,
        "text",
        escape(value),
        x=x,
        y=y,
        font_size=size,
        font_weight=weight,
        fill=color,
        text_anchor=anchor,
        font_family=family,
        opacity=opacity,
    )


def multiline(
    parts: list[str],
    x: float,
    y: float,
    lines: list[str],
    size: int = 17,
    line_height: int = 24,
    weight: int = 500,
    color: str = COLORS["ink"],
    anchor: str = "middle",
    family: str | None = None,
) -> None:
    tspans = []
    for index, line in enumerate(lines):
        dy = 0 if index == 0 else line_height
        tspans.append(
            f'<tspan x="{x}" dy="{dy}">{escape(line)}</tspan>'
        )
    add(
        parts,
        "text",
        "".join(tspans),
        x=x,
        y=y,
        font_size=size,
        font_weight=weight,
        fill=color,
        text_anchor=anchor,
        font_family=family,
    )


def path(
    parts: list[str],
    points: list[tuple[float, float]],
    color: str,
    width: float = 4,
    dashed: bool = False,
    arrow_end: bool = True,
    arrow_start: bool = False,
    opacity: float = 1.0,
) -> None:
    d = "M " + " L ".join(f"{x} {y}" for x, y in points)
    marker = {
        COLORS["data"]: "arrow-data",
        COLORS["control"]: "arrow-control",
        COLORS["feedback"]: "arrow-feedback",
        COLORS["trap"]: "arrow-trap",
        COLORS["memory"]: "arrow-memory",
    }[color]
    add(
        parts,
        "path",
        d=d,
        fill="none",
        stroke=color,
        stroke_width=width,
        stroke_linejoin="round",
        stroke_linecap="round",
        stroke_dasharray="10 8" if dashed else None,
        marker_end=f"url(#{marker})" if arrow_end else None,
        marker_start=f"url(#{marker})" if arrow_start else None,
        opacity=opacity,
    )


def label(
    parts: list[str],
    x: float,
    y: float,
    value: str,
    color: str,
    width: float | None = None,
) -> None:
    label_width = width or max(70, len(value) * 10 + 20)
    rect(parts, x - label_width / 2, y - 17, label_width, 28, "#FFFFFF", "#D8E2EC", 1, 8)
    text(parts, x, y + 3, value, 13, 600, color)


def block(
    parts: list[str],
    x: float,
    y: float,
    width: float,
    height: float,
    title: str,
    module: str,
    lines: list[str],
    fill: str,
    stroke: str,
    title_size: int = 19,
    module_size: int = 12,
) -> None:
    rect(parts, x, y, width, height, fill, stroke, 2.2, 14, "block")
    text(parts, x + width / 2, y + 29, title, title_size, 700, COLORS["ink"])
    text(
        parts,
        x + width / 2,
        y + 50,
        module,
        module_size,
        600,
        COLORS["muted"],
        family="Consolas, 'Courier New', monospace",
    )
    if lines:
        multiline(parts, x + width / 2, y + 74, lines, 13, 19, 500, COLORS["muted"])


def stage_panel(
    parts: list[str],
    x: float,
    width: float,
    title: str,
    subtitle: str,
    fill: str,
) -> None:
    rect(parts, x, 145, width, 490, fill, "#C6D6E5", 1.5, 18, dash="7 7")
    text(parts, x + width / 2, 177, title, 21, 750, COLORS["ink"])
    text(parts, x + width / 2, 199, subtitle, 12, 600, COLORS["muted"])


def pipeline_register(
    parts: list[str], x: float, title: str, lines: list[str]
) -> None:
    rect(parts, x, 238, 62, 275, COLORS["reg_fill"], "#849BB1", 2.2, 12, "block")
    text(parts, x + 31, 268, title, 15, 750, COLORS["ink"])
    add(parts, "line", x1=x + 10, y1=282, x2=x + 52, y2=282, stroke="#9EB1C3", stroke_width=1.5)
    multiline(parts, x + 31, 309, lines, 11, 25, 600, COLORS["muted"])


def marker_def(marker_id: str, color: str) -> str:
    return (
        f'<marker id="{marker_id}" viewBox="0 0 10 10" refX="8" refY="5" '
        'markerWidth="7" markerHeight="7" orient="auto-start-reverse">'
        f'<path d="M 0 0 L 10 5 L 0 10 z" fill="{color}"/></marker>'
    )


def generate_svg() -> str:
    parts: list[str] = []
    parts.append('<?xml version="1.0" encoding="UTF-8"?>')
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" '
        f'viewBox="0 0 {WIDTH} {HEIGHT}" role="img" aria-labelledby="title desc">'
    )
    parts.append('<title id="title">RV64五级流水线CPU总体结构图</title>')
    parts.append(
        '<desc id="desc">展示IF、ID、EX、MEM、WB五级流水线，I-Cache、D-Cache、'
        '前递、冒险检测、分支预测、CSR和Trap控制关系。</desc>'
    )
    parts.append("<defs>")
    for name, key in [
        ("arrow-data", "data"),
        ("arrow-control", "control"),
        ("arrow-feedback", "feedback"),
        ("arrow-trap", "trap"),
        ("arrow-memory", "memory"),
    ]:
        parts.append(marker_def(name, COLORS[key]))
    parts.append(
        '<filter id="soft-shadow" x="-20%" y="-20%" width="140%" height="150%">'
        '<feDropShadow dx="0" dy="3" stdDeviation="4" flood-color="#183B56" '
        'flood-opacity="0.13"/></filter>'
    )
    parts.append("</defs>")
    add(parts, "rect", x=0, y=0, width=WIDTH, height=HEIGHT, fill="#FFFFFF")

    text(parts, 55, 54, "RV64 RTL Architecture Lab", 34, 800, COLORS["ink"], "start")
    text(
        parts,
        55,
        84,
        "单发射 · 顺序执行/提交 · 前递与冒险检测 · 可配置竞赛预测 · 阻塞式 I/D Cache · 机器模式 Trap/CSR",
        16,
        500,
        COLORS["muted"],
        "start",
    )

    legend_items = [
        (COLORS["data"], "主数据通路", False),
        (COLORS["control"], "暂停与流水线控制", True),
        (COLORS["feedback"], "预测/前递反馈", True),
        (COLORS["trap"], "Trap、冲刷与重定向", True),
        (COLORS["memory"], "Cache后端握手", False),
    ]
    legend_x = 850
    for color, name, dashed in legend_items:
        add(
            parts,
            "line",
            x1=legend_x,
            y1=67,
            x2=legend_x + 42,
            y2=67,
            stroke=color,
            stroke_width=4,
            stroke_dasharray="8 6" if dashed else None,
        )
        text(parts, legend_x + 51, 72, name, 13, 600, COLORS["muted"], "start")
        legend_x += 190

    # Stage backgrounds.
    stage_panel(parts, 45, 310, "IF", "取指", COLORS["if_fill"])
    stage_panel(parts, 365, 80, "IF/ID", "流水线寄存器", "#F3F6F9")
    stage_panel(parts, 455, 300, "ID", "译码与寄存器读取", COLORS["id_fill"])
    stage_panel(parts, 765, 75, "ID/EX", "流水线寄存器", "#F3F6F9")
    stage_panel(parts, 850, 300, "EX", "执行、分支与CSR运算", COLORS["ex_fill"])
    stage_panel(parts, 1160, 75, "EX/MEM", "流水线寄存器", "#F3F6F9")
    stage_panel(parts, 1245, 300, "MEM", "访存、提交前检查", COLORS["mem_fill"])
    stage_panel(parts, 1555, 75, "MEM/WB", "流水线寄存器", "#F3F6F9")
    stage_panel(parts, 1640, 235, "WB", "写回", COLORS["wb_fill"])

    # Primary data paths, drawn before the blocks so arrow tips meet edges.
    path(parts, [(150, 286), (180, 286)], COLORS["data"], 5)
    path(parts, [(335, 286), (380, 286)], COLORS["data"], 5)
    path(parts, [(442, 260), (485, 250)], COLORS["data"], 3.5)
    path(parts, [(442, 330), (485, 330)], COLORS["data"], 5)
    path(parts, [(725, 357), (775, 357)], COLORS["data"], 5)
    path(parts, [(837, 357), (875, 357)], COLORS["data"], 5)
    path(parts, [(965, 372), (1000, 372)], COLORS["data"], 5)
    path(parts, [(1125, 370), (1170, 370)], COLORS["data"], 5)
    path(parts, [(1232, 315), (1280, 295)], COLORS["data"], 5)
    path(parts, [(1505, 295), (1565, 295)], COLORS["data"], 5)
    path(parts, [(1627, 342), (1670, 335)], COLORS["data"], 5)
    path(parts, [(1232, 450), (1260, 450), (1260, 585), (1535, 585), (1535, 450), (1565, 450)], COLORS["data"], 4)
    path(parts, [(1758, 390), (1758, 608), (600, 608), (600, 410)], COLORS["data"], 4)

    # Prediction and forwarding feedback paths.
    path(parts, [(250, 350), (250, 420)], COLORS["feedback"], 3.5, True)
    path(parts, [(70, 465), (55, 465), (55, 286), (70, 286)], COLORS["feedback"], 3.5, True)
    path(parts, [(1198, 513), (1198, 565), (335, 565), (335, 465)], COLORS["feedback"], 3.5, True)
    path(parts, [(1198, 513), (1198, 525), (1125, 525)], COLORS["feedback"], 3.5, True)
    path(parts, [(1595, 513), (1595, 552), (1125, 552)], COLORS["feedback"], 3.5, True)
    path(parts, [(990, 465), (990, 438), (920, 438), (920, 425)], COLORS["feedback"], 3.5, True)

    # Cache-to-backing-memory request/response paths.
    path(parts, [(335, 325), (350, 325), (350, 820), (210, 820), (210, 855)], COLORS["memory"], 4, False, True, True)
    path(parts, [(1392, 355), (1392, 820), (1600, 820), (1600, 855)], COLORS["memory"], 4, False, True, True)

    # Inputs into the centralized top-level pipeline-control logic.
    path(parts, [(670, 500), (670, 675)], COLORS["control"], 3.5, True)
    path(parts, [(335, 375), (420, 375), (420, 700), (460, 700)], COLORS["control"], 3.5, True)
    path(parts, [(1392, 355), (1468, 355), (1468, 700), (1460, 700)], COLORS["control"], 3.5, True)
    path(parts, [(1198, 513), (1198, 675)], COLORS["feedback"], 3.5, True)
    path(parts, [(1160, 850), (1160, 755)], COLORS["trap"], 4, True)

    # Pipeline-control outputs: PC redirect/write and register hold/flush.
    path(parts, [(460, 730), (25, 730), (25, 305), (70, 305)], COLORS["trap"], 4, True)
    path(parts, [(600, 675), (600, 645), (411, 645), (411, 513)], COLORS["control"], 3.5, True)
    path(parts, [(800, 675), (800, 513)], COLORS["control"], 3.5, True)
    path(parts, [(1200, 675), (1200, 513)], COLORS["control"], 3.5, True)

    # CSR and trap subsystem connections.
    path(parts, [(595, 845), (595, 635), (650, 635), (650, 410)], COLORS["feedback"], 3.5, True)
    path(parts, [(875, 870), (875, 780), (700, 780), (700, 410)], COLORS["feedback"], 3.5, True)
    path(parts, [(1325, 475), (1325, 805), (1160, 805), (1160, 850)], COLORS["trap"], 4, True)
    path(parts, [(1030, 905), (720, 905)], COLORS["trap"], 3.5, True)
    path(parts, [(1160, 1010), (1160, 980)], COLORS["trap"], 3.5)
    path(parts, [(1198, 513), (1198, 790), (650, 790), (650, 845)], COLORS["feedback"], 3.5, True)

    # Main blocks.
    block(parts, 70, 245, 80, 82, "PC", "u_pc", ["64-bit"], COLORS["if_fill"], COLORS["data"], 20)
    block(parts, 180, 225, 155, 125, "I-Cache", "u_icache", ["直接映射 · 阻塞式", "8行 × 32B"], COLORS["cache_fill"], COLORS["memory"])
    block(parts, 70, 420, 265, 90, "可配置分支预测", "u_branchpredictionunit", ["BHT / 全局相关 / 竞赛"], "#F2EFFF", COLORS["feedback"])

    pipeline_register(parts, 380, "IF/ID", ["PC", "Instr", "Predict", "Valid"])

    block(parts, 485, 215, 240, 70, "控制译码", "u_control", [], COLORS["id_fill"], COLORS["control"])
    block(parts, 485, 305, 240, 105, "通用寄存器堆", "u_register", ["32 × 64-bit · 双读单写"], COLORS["id_fill"], COLORS["data"])
    block(parts, 485, 440, 115, 60, "立即数", "u_immgen", [], COLORS["id_fill"], COLORS["data"], 16)
    block(parts, 615, 440, 110, 60, "冒险检测", "u_hazarddetectionunit", [], "#FFF7E9", COLORS["control"], 15, 8)

    pipeline_register(parts, 775, "ID/EX", ["Operands", "Imm", "Control", "CSR", "Valid"])

    block(parts, 875, 220, 110, 65, "ALU控制", "u_alucontrol", [], COLORS["ex_fill"], COLORS["control"], 16)
    block(parts, 875, 320, 90, 105, "操作数选择", "Forward MUX", ["A / B"], COLORS["ex_fill"], COLORS["feedback"], 15)
    block(parts, 1000, 300, 125, 140, "ALU", "u_alu", ["整数运算", "地址计算", "CSR运算"], COLORS["ex_fill"], COLORS["data"], 22)
    block(parts, 875, 465, 250, 75, "数据前递", "u_forwardingunit", ["EX/MEM、MEM/WB → EX"], "#F2EFFF", COLORS["feedback"], 17)

    pipeline_register(parts, 1170, "EX/MEM", ["ALU", "Store", "Branch", "Exception", "CSR", "Valid"])

    block(parts, 1280, 235, 225, 120, "D-Cache", "u_dcache", ["直接映射 · 阻塞式", "写穿透 · 不写分配"], COLORS["cache_fill"], COLORS["memory"])
    block(parts, 1280, 385, 225, 90, "MEM提交前检查", "top-level logic", ["对齐、valid与副作用屏蔽"], COLORS["mem_fill"], COLORS["trap"], 17)

    pipeline_register(parts, 1565, "MEM/WB", ["ALU", "Load", "PC+4", "CSR", "Control", "Valid"])
    block(parts, 1670, 280, 175, 110, "写回选择", "WB MUX", ["ALU / Load", "PC+4 / CSR"], COLORS["wb_fill"], COLORS["data"])

    # Centralized control band.
    rect(parts, 460, 675, 1000, 80, "#FFF9F0", COLORS["control"], 2.2, 16, "block")
    text(parts, 960, 706, "顶层流水线控制", 21, 750, COLORS["ink"])
    text(parts, 960, 734, "PCwrite · 各级 hold/flush · Cache stall · 分支恢复 · Trap/MRET 重定向", 15, 600, COLORS["muted"])

    # Lower subsystem blocks.
    block(parts, 70, 855, 280, 115, "指令后端存储器", "u_icache_backing_memory", ["64-bit接口 · 固定3周期模型", "每条Cache Line读取4次"], "#ECFAF6", COLORS["memory"])
    block(parts, 470, 845, 250, 135, "机器模式 CSR", "u_csrfile", ["mstatus · mtvec", "mepc · mcause", "Trap/MRET状态更新"], "#FFF6E8", COLORS["control"])
    block(parts, 770, 870, 210, 90, "CSR前递", "u_csrforwardingunit", ["EX/MEM → ID"], "#F2EFFF", COLORS["feedback"])
    block(parts, 1030, 850, 260, 130, "异常与中断控制", "u_trapcontrolunit", ["非法指令 · ECALL", "指令/Load/Store未对齐", "外部中断"], "#FFF0F0", COLORS["trap"])
    block(parts, 1450, 855, 300, 115, "数据后端存储器", "u_dcache_backing_memory", ["64-bit请求/响应接口", "Load填充与Store写穿透"], "#ECFAF6", COLORS["memory"])

    # External interrupt input.
    rect(parts, 1060, 1010, 200, 45, "#FFFFFF", COLORS["trap"], 1.8, 12)
    text(parts, 1160, 1039, "external_interrupt_pending", 13, 650, COLORS["trap"], family="Consolas, monospace")

    # Connection labels.
    label(parts, 165, 274, "PC", COLORS["data"], 50)
    label(parts, 357, 274, "instruction", COLORS["data"], 92)
    label(parts, 747, 344, "rs1 / rs2", COLORS["data"], 88)
    label(parts, 1148, 356, "result", COLORS["data"], 68)
    label(parts, 1535, 281, "Load data", COLORS["data"], 82)
    label(parts, 1397, 574, "ALU / PC+4 / CSR旁路", COLORS["data"], 170)
    label(parts, 1030, 597, "WB写回反馈", COLORS["data"], 105)
    label(parts, 474, 552, "MEM结果训练预测器", COLORS["feedback"], 140)
    label(parts, 1380, 690, "D-Cache stall", COLORS["control"], 108)
    label(parts, 385, 690, "I-Cache等待", COLORS["control"], 98)
    label(parts, 47, 705, "redirect", COLORS["trap"], 72)
    label(parts, 217, 808, "req / resp", COLORS["memory"], 90)
    label(parts, 1575, 808, "req / resp", COLORS["memory"], 90)
    label(parts, 1120, 790, "异常信息", COLORS["trap"], 78)

    # Scope note.
    rect(parts, 70, 1090, 1680, 68, COLORS["panel"], "#D6E1EC", 1.4, 14)
    text(parts, 95, 1118, "当前范围", 15, 750, COLORS["ink"], "start")
    text(
        parts,
        190,
        1118,
        "单发射、顺序流水线；Cache一次仅处理一个访问；无MSHR、无一致性、无乱序访存；D-Cache miss期间冻结流水线并推迟外部中断。",
        14,
        550,
        COLORS["muted"],
        "start",
    )
    text(parts, 95, 1144, "图示原则", 15, 750, COLORS["ink"], "start")
    text(parts, 190, 1144, "保留模块边界与关键握手关系；省略位级MUX、比较器及数组内部连线。", 14, 550, COLORS["muted"], "start")

    text(parts, 1850, 1178, "Generated from the current RTL structure", 11, 500, "#8295A7", "end")
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(generate_svg(), encoding="utf-8")
    print(f"Generated {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
