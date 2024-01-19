# Progo1

## Q1: different thread numbers' speedup

| speedup | thread_num |
| ------- | ---------- |
| 1.98    | 2          |
| 1.64    | 3          |
| 2.45    | 4          |
| 2.49    | 5          |
| 3.26    | 6          |
| 3.41    | 7          |
| 4.01    | 8          |

<img src="C:\Users\Edward\OneDrive\STUDY\Code\CS149\asst1\image-1.png" alt="image-20231017162149986" style="zoom: 67%;" />

* It's easy to find that when number of threads is even, the speedup is better, I guess the reason is **load balance** 

* It's obvious that when number of thread is 3, the speedup is even lower than 2 threads working. Next I will talk about it.

## Q2: Dive  into each thread's computation

1. Control the ```--threads=2``` and run the program, result is as below:
   
   ```bash
   [mandelbrot serial]:            [299.755] ms
   Wrote image file mandelbrot-serial.ppm
   Thread 0 spends 154.552 ms to compute
   Thread 1 spends 155.345 ms to compute
   Thread 0 spends 151.089 ms to compute
   Thread 1 spends 151.213 ms to compute
   Thread 0 spends 151.5 ms to compute
   Thread 1 spends 151.86 ms to compute
   Thread 1 spends 150.972 ms to compute
   Thread 0 spends 151.186 ms to compute
   Thread 0 spends 149.997 ms to compute
   Thread 1 spends 150.461 ms to compute
   [mandelbrot thread]:            [150.572] ms
   Wrote image file mandelbrot-thread.ppm
                                (1.99x speedup from 2 threads
   ```

2. let ```--threads=3``` and run the program, result is:
   
   ```bash
   [mandelbrot serial]:            [300.283] ms
   Wrote image file mandelbrot-serial.ppm
   Thread 0 spends 60.1191 ms to compute
   Thread 2 spends 61.2318 ms to compute
   Thread 1 spends 185.061 ms to compute
   Thread 0 spends 59.3586 ms to compute
   Thread 2 spends 61.0717 ms to compute
   Thread 1 spends 183.425 ms to compute
   Thread 2 spends 59.5588 ms to compute
   Thread 0 spends 59.91 ms to compute
   Thread 1 spends 185.365 ms to compute
   Thread 2 spends 59.6913 ms to compute
   Thread 0 spends 59.8839 ms to compute
   Thread 1 spends 183.473 ms to compute
   Thread 2 spends 60.3851 ms to compute
   Thread 0 spends 60.6459 ms to compute
   Thread 1 spends 184.866 ms to compute
   [mandelbrot thread]:            [183.580] ms
   Wrote image file mandelbrot-thread.ppm
                                (1.64x speedup from 3 threads)
   ```

### Summary

- Obviously, when the number of thread is 3, the thread which thread_id is 1, has much lower computation, so other threads are waiting it to finish, therefore, the speedup is even lower.

## Q3: better work load

- just as the code show (the thread_v2 interface), we can split the data into n pieces, (n is number of threads), and the split the block into n pieces for each thread. So we can gain better result below. (PS. if you dive into my code, you will see I actually use 64 threads, lol. but my v2 interface did better than v1)
  
  ```bash
  [mandelbrot serial]:            [301.738] ms
  Wrote image file mandelbrot-serial.ppm
  [mandelbrot thread]:            [26.449] ms
  Wrote image file mandelbrot-thread.ppm
                                (11.41x speedup from 8 threads)
  ```

---

# Prog2

## Q1 : why vector_width increase, the utilization of vector decrease?

- A simple hypothesis,  I think that, when vector width increases, it should be more efficiently, but we have a **while loop**, which means, it's **the bottleneck of this whole program**. The more vector width, the more time to wait.

---

# Prog3

## Q1: Why my ispc program speedup didn't be 8? Instead, 5.73

```bash
5.73 speedup from ISPC
```

- Ans: ISPC uses SPMD method, at the bottom layer, still uses SIMD instruction. When we use SIMD instruction manually, still we can't get ideal speedup. This program, as we can observe, the x, y and output pointer are both uniform, frequently R&W operations can make our program slower than our imagine.

## Ｑ2: Why use `--tasks` can accelerate so much?

- **Ans**: Because the task mechanism uses **multi-core** parallel computing, and if use `foreach`only, the program only computes on the ***single core***!!!
- Test： When the task number increases, the speedup increases too. 

| task number | speedup ratio |
|:-----------:|:-------------:|
| 1           | 5.73          |
| 2           | 11.44         |
| 4           | 14.49         |
| 8           | 23.28         |
| 16          | 40.86         |

- As table shown above, when use two core to compute, the ratio is roughly twice than one core, but with the the core num increases, the ratio increases slower than core num, because the job of map still takes time, and other reasons to drag our parallel computing.

## Q3: What's the difference between task and thread?

- **Ans**:  As new Bing suggested, the difference may be  below:

> ISPC is a language for vectorized programming that supports two parallel execution modes: SPMD (Single Program Multiple Data) and task (task).
> 
> SPMD mode refers to using SIMD instructions to process different data in parallel on a CPU core. The ISPC compiler will divide the program into multiple program instances, each instance corresponding to a vector channel, and execute the same instructions at the same time.
> 
> Task mode refers to using multiple threads to execute different tasks in parallel on multiple CPU cores. The ISPC compiler will divide the program into multiple tasks, and each task can contain multiple program instances, scheduled and executed by different cores.
> 
> The main differences between task mechanism and multi-threading are as follows:
> 
> - The task mechanism is part of the ISPC language, and multi-threading is a concept of the operating system.
> - The task mechanism is an extension based on the SPMD mode. Each task is an SPMD program, and multi-threads can execute arbitrary code.
> - The task mechanism does not guarantee the execution order and concurrency of tasks, but **multi-threads can control the execution order and concurrency of threads through the synchronization mechanism**.
> - The task mechanism does not require explicit creation and destruction of tasks, while multi-threading requires calling the operating system's API to create and destroy threads.
> - **The task mechanism can automatically balance the load and distribution of tasks, while multi-threading requires manual management of the load and distribution of threads**.

---

# Prog4 sqrt

## Q1: compile with default settings

```bash
[sqrt serial]:          [641.218] ms
[sqrt ispc]:            [132.223] ms
[sqrt task ispc]:       [13.266] ms
                                (4.85x speedup from ISPC)
                                (48.34x speedup from task ISPC)
```

## Q2: change the init values to get max speedup

- when change the init values to be `2.99f`, and we can see the result as below:

```bash
[sqrt serial]:          [951.407] ms
[sqrt ispc]:            [144.749] ms
[sqrt task ispc]:       [14.474] ms
                                (6.57x speedup from ISPC)
                                (65.73x speedup from task ISPC)
```

    we can easily find the  speedup both increases. It's easy to understand, because the more computation steps, the more parallel computing gains. @

## Q3: change the init values to get min speedup

- when change the init values to be `1.0f` , and we can see the sppedup:

```bash
[sqrt serial]:          [14.579] ms
[sqrt ispc]:            [12.675] ms
[sqrt task ispc]:       [13.699] ms
                                (1.15x speedup from ISPC)
                                (1.06x speedup from task ISPC)
```

- Because when init values are 1, it only need one step to get the answer. so the bottleneck is I/O.

---

# Progo5 saxpy

## Q1: build the program, and explain the result

1. The result is below:

```bash
[saxpy ispc]:           [15.626] ms     [19.072] GB/s   [2.560] GFLOPS
[saxpy task ispc]:      [17.850] ms     [16.696] GB/s   [2.241] GFLOPS
                                (0.88x speedup from use of tasks)
```

2. Optimization: 
   
   1. Use proper task number: When I change the  tasks numbers to **16** , the speedup can be better than starter code. Because my computer only has 16 cores.
      
      ```bash
      [saxpy ispc]:           [17.044] ms     [17.485] GB/s   [2.347] GFLOPS
      [saxpy task ispc]:      [17.814] ms     [16.730] GB/s   [2.245] GFLOPS
                                      (0.96x speedup from use of tasks)
      ```
   
   2. Make the data size to be bigger, but can reach the bandwidth of GDRAM, so it's result may be worse. 
   
   3. Summary: this program's bottleneck is I/O, so there is so tight zone for optimizer.

---

# Prog6 Make k-means be faster