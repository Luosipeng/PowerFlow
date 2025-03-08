# todo list:
# 1. test the gpu based algorithms
# 2. test the cgs solvers

function mplinsolve(A, b, solver = "", opt = nothing)
    info = nothing

    if solver in ["", "\\"]
        x = A \ b
    elseif solver == "LU3"
        q = amd(A)
        if issparse(A)
            L, U, p = lu(A[q,q], Val(true))
        else
            L, U, p = lu(A[q,q])
        end
        x = zeros(size(A, 1))
        x[q] = U \ (L \ b[q[p]])
    elseif solver == "LU3a"
        q = amd(A)
        L, U, p = lu(A[q,q])
        x = zeros(size(A, 1))
        x[q] = U \ (L \ b[q[p]])
    elseif solver == "LU4"
        L, U, p, q = lu(A)
        x = zeros(size(A, 1))
        x[q] = U \ (L \ b[p])
    elseif solver == "LU5"
        L, U, p, q, R = lu(A)
        x = zeros(size(A, 1))
        x[q] = U \ (L \ (R[:, p] \ b))
    elseif solver == "cholesky"
        factor = cholesky(A)
        x = factor \ b
    elseif solver == "gmres"
        ilu_fact = ilu(A)
        x = IterativeSolvers.gmres(A, b, Pl=ilu_fact, reltol=1e-8, maxiter = 1000)
    elseif solver == "bicgstab"
        n = size(A,1)
        F = ilu(A, τ = 0.05)
        opM = LinearOperator(Float64, n, n, false, false, (y, v) -> forward_substitution!(y, F, v))
        opN = LinearOperator(Float64, n, n, false, false, (y, v) -> backward_substitution!(y, F, v))
        x , stats = bicgstab(A, b, history=false, M=opM, N=opN)
    elseif solver == "cgs"
        x = cgs(A, b, rtol=1e-8, itmax=1000)
    # elseif solver == "gpu"
    #     if Sys.iswindows()
    #         # # Convert A and b to GPU arrays
    #         A_gpu = CUDA.CUSPARSE.CuSparseMatrixCSR(sparse(A))
    #         b_gpu = CUDA.CuArray(b)
    #         # Create a diagonal preconditioner
    #         M_inv = 1 ./ diag(A)
    #         M_inv_gpu = CUDA.CuArray(M_inv)
    #         # Create an instance of the preconditioner
    #         P = MyPreconditioner(M_inv_gpu)
    #         # Solve the system on the GPU using the GMRES method with preconditioning
    #         x_gpu, stats = Krylov.gmres(A_gpu, b_gpu, M=P)
    #         # Convert x_gpu back to a CPU array
    #         x = Array(x_gpu)
    #         # Convert A and b to GPU arrays
            
    #         # A_gpu = CUDA.CUSPARSE.CuSparseMatrixCSR(sparse(A))
    #         # b_gpu = CUDA.CuArray(b)
    #         # # Create a diagonal preconditioner with diagonal shifting
    #         # epsilon = 1e-6  # Small constant to avoid division by zero
    #         # M_inv = 1 ./ (diag(A) .+ epsilon)
    #         # M_inv_gpu = CUDA.CuArray(M_inv)
    #         # # Create an instance of the preconditioner
    #         # P = Diagonal(M_inv_gpu)
    #         # # Apply the preconditioner to b
    #         # b_gpu = P * b_gpu
    #         # # Solve the system on the GPU using the GMRES method with preconditioning
    #         # x_gpu, stats = Krylov.gmres(A_gpu, b_gpu, M=P)
    #         # # Convert x_gpu back to a CPU array
    #         # x = Array(x_gpu)

    #         # A = Float32.(A)
    #         # b = Float32.(b)
    #         # d_A = CuSparseMatrixCSC(A)
    #         # d_b = CuArray(b)
    #         # d_x, stats = bicgstab(d_A, d_b)
    #         # x = Array(d_x)
    #     elseif Sys.isapple()
    #         A_gpu = MtlMatrix(Float32.(A))
    #         b_gpu = MtlVector(Float32.(b))
    #         x_gpu = Krylov.gmres(A_gpu, b_gpu)
    #         x = collect(x_gpu)
    #     else
    #         error("mplinsolve: GPU is not supported on this platform.")    
    #     end
    # elseif solver=="gmresJacobi"
    #     # Move A and b to the GPU
    #     A_gpu = CUDA.CuArray(A)
    #     b_gpu = CUDA.CuArray(b)
    #     # Compute the Jacobi preconditioner on the CPU and move it to the GPU
    #     M_cpu = Diagonal(1 ./ diag(A))
    #     M_gpu = CUDA.CuArray(M_cpu)
    #      # Define the linear operator for the preconditioner
    #     opM = LinearOperator(Float64, size(A, 1), size(A, 2), false, false, (y, v) -> mul!(y, M_gpu, v))
    #     # Solve Ax = b using GMRES with preconditioner
    #     x_gpu , stats = Krylov.gmres(A_gpu, b_gpu, M=opM)
    #     x = collect(x_gpu)
    # elseif solver=="gmresJACOBI"
    #     # Move A and b to the GPU
    #     tol=1e-6
    #     x0=zeros(length(b))
    #     x,res,m=gpu_gmres_jacobi(A,x0,tol,b)
    else
        error("mplinsolve: '$solver' is not a valid value for SOLVER, using default.")
        x = A \ b
    end

    return x, info
end

# function vstr2num_(vstr)
#     pat = r"\.?(\d+)"
#     m = match(pat, vstr)
#     b = 1
#     num = 0
#     for k in m.captures
#         num += b * parse(Int, k)
#         b /= 1000
#     end
#     return num
# end
#  # Define a custom type that represents the preconditioner
#  struct MyPreconditioner
#     M_inv::CUDA.CuArray{Float64}
# end

# # Define the multiplication operation for the preconditioner
# function LinearAlgebra.mul!(y::CUDA.CuArray, P::MyPreconditioner, x::CUDA.CuArray)
#     y .= P.M_inv .* x
#     return y
# end