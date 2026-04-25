"""简单的计算器模块，用于测试Subagent架构。"""


def add(a: float, b: float) -> float:
    """返回两个数的和。

    Args:
        a: 第一个数
        b: 第二个数

    Returns:
        两个数的和
    """
    return a + b


def subtract(a: float, b: float) -> float:
    """返回两个数的差。

    Args:
        a: 第一个数
        b: 第二个数

    Returns:
        a 减 b 的差
    """
    return a - b


def multiply(a: float, b: float) -> float:
    """返回两个数的积。

    Args:
        a: 第一个数
        b: 第二个数

    Returns:
        两个数的积
    """
    return a * b


def divide(a: float, b: float) -> float | None:
    """返回两个数的商。

    Args:
        a: 被除数
        b: 除数

    Returns:
        a 除以 b 的商，如果除数为零则返回 None
    """
    if b == 0:
        return None
    return a / b