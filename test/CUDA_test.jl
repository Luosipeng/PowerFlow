using CUDA

# Define a kernel function
# function kernel_add!(C, A, B)
#     i = threadIdx().x
#     C[i] = A[i] + B[i]
#     return
# end

# # Allocate memory on the GPU
# N = 1024000
# A = CUDA.fill(1.0, N)
# B = CUDA.fill(2.0, N)
# C = CUDA.fill(0.0, N)

# # Launch the kernel
# @time @cuda threads=1024 kernel_add!(C, A, B)

# # Transfer the result back to the CPU
# C_cpu = Array(C);