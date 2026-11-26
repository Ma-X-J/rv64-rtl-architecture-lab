static volatile int values[8] = {3, 1, 4, 1, 5, 9, 2, 6};

__attribute__((noinline))
int sum_array(volatile const int *data, int length)
{
    int sum = 0;

    for (int i = 0; i < length; ++i)
        sum += data[i];

    return sum;
}

int main(void)
{
    return sum_array(values, 8);
}
