# Define the newtonpf function
function newtondcpf(baseMVA, bus, gen, load, Ybus, V0, ref, p, tol0, max_it0, alg="")
    tol = tol0
    max_it = max_it0
    lin_solver = Char[]
    
    # Initialize
    converged = false
    i = 0
    V = V0
    
    
    # Set up indexing for updating V
    np = length(p)
    j1 = 1; j2 = np; # j1:j2 - V angle of pv buses
    # Evaluate F(x0)
    mis = V .* conj.(Ybus * V) - PowerFlow.makeSbus(baseMVA, bus, gen, V, load)
    F = real(mis[p])
     # Check tolerance
    normF = norm(F, Inf)
    if normF < tol
        converged = true
    end
    # Do Newton iterations
    while (!converged && i < max_it)

        # Update iteration counter
        i += 1

        # Evaluate Jacobian
        dSbus_dVa, dSbus_dVm = PowerFlow.dSbus_dV(Ybus, V)
        neg_dSd_dVm = PowerFlow.makeSbus(baseMVA, bus, gen, V, load, return_derivative=true)
        dSbus_dVm .-= neg_dSd_dVm

        J = real(dSbus_dVm[p,p])

        # Compute update step
        # @time begin
        # dx, info = julinsolve(J, -F, alg)
        dx = J \ -F
        
        # end
        #precision control
        #dx = round.(dx, digits=6)

        # Update voltage
        if np > 0
            V[p] .+= dx[j1:j2]
        end
        

        # Evaluate F(x)
        mis = V .* conj.(Ybus * V) - PowerFlow.makeSbus(baseMVA, bus, gen, V, load)
        F = real(mis[p])

        # Check for convergence
        normF = norm(F, Inf)
        if normF < tol
            converged = true
        end
    end

    return V, converged, i
end