__attribute__((noinline))
int add_zero(int value)
{
    return value + 0;
}

int main(void)
{
    return add_zero(42);
}
