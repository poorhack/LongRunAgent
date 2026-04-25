"""计算器模块的测试文件。"""

import pytest
from src.calculator import add, subtract, multiply, divide


class TestAdd:
    """测试加法函数。"""

    def test_add_positive_numbers(self):
        """测试正数相加。"""
        assert add(2, 3) == 5

    def test_add_negative_numbers(self):
        """测试负数相加。"""
        assert add(-2, -3) == -5

    def test_add_mixed_numbers(self):
        """测试正负数混合相加。"""
        assert add(-2, 3) == 1

    def test_add_zero(self):
        """测试与零相加。"""
        assert add(5, 0) == 5

    def test_add_floats(self):
        """测试浮点数相加。"""
        assert add(2.5, 3.5) == 6.0


class TestSubtract:
    """测试减法函数。"""

    def test_subtract_positive_numbers(self):
        """测试正数相减。"""
        assert subtract(5, 3) == 2

    def test_subtract_negative_numbers(self):
        """测试负数相减。"""
        assert subtract(-5, -3) == -2

    def test_subtract_mixed_numbers(self):
        """测试正负数混合相减。"""
        assert subtract(-5, 3) == -8

    def test_subtract_zero(self):
        """测试与零相减。"""
        assert subtract(5, 0) == 5

    def test_subtract_floats(self):
        """测试浮点数相减。"""
        assert subtract(5.5, 2.5) == 3.0


class TestMultiply:
    """测试乘法函数。"""

    def test_multiply_positive_numbers(self):
        """测试正数相乘。"""
        assert multiply(2, 3) == 6

    def test_multiply_negative_numbers(self):
        """测试负数相乘。"""
        assert multiply(-2, -3) == 6

    def test_multiply_mixed_numbers(self):
        """测试正负数混合相乘。"""
        assert multiply(-2, 3) == -6

    def test_multiply_by_zero(self):
        """测试与零相乘。"""
        assert multiply(5, 0) == 0

    def test_multiply_floats(self):
        """测试浮点数相乘。"""
        assert multiply(2.5, 2) == 5.0


class TestDivide:
    """测试除法函数。"""

    def test_divide_positive_numbers(self):
        """测试正数相除。"""
        assert divide(6, 3) == 2

    def test_divide_negative_numbers(self):
        """测试负数相除。"""
        assert divide(-6, -3) == 2

    def test_divide_mixed_numbers(self):
        """测试正负数混合相除。"""
        assert divide(-6, 3) == -2

    def test_divide_by_zero(self):
        """测试除以零。"""
        assert divide(5, 0) is None

    def test_divide_floats(self):
        """测试浮点数相除。"""
        assert divide(5.0, 2) == 2.5

    def test_divide_zero_by_number(self):
        """测试零除以数。"""
        assert divide(0, 5) == 0