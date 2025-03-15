# Define the newtonpf function
function newtonpf(baseMVA,bus,gen,load, Ybus, V0, ref, pv, pq, tol0, max_it0, alg="bicgstab")
    tol = tol0
    max_it = max_it0
    lin_solver = Char[]
    
    # Initialize
    converged = false
    i = 0
    V = V0
    Va = angle.(V)
    Vm = abs.(V)
    
    # Set up indexing for updating V
    npv = length(pv)
    npq = length(pq)
    j1 = 1; j2 = npv; # j1:j2 - V angle of pv buses
    j3 = j2 + 1; j4 = j2 + npq; # j3:j4 - V angle of pq buses
    j5 = j4 + 1; j6 = j4 + npq; # j5:j6 - V mag of pq buses
    # Evaluate F(x0)
    mis = V .* conj.(Ybus * V) - PowerFlow.makeSbus(baseMVA, bus, gen, Vm, load)
    F = [real(mis[vcat(pv, pq)]); imag(mis[pq])]
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
        neg_dSd_dVm = PowerFlow.makeSbus(baseMVA, bus, gen, Vm, load, return_derivative=true)
        dSbus_dVm .-= neg_dSd_dVm

        #precision control
        #dSbus_dVa = round.(dSbus_dVa, digits=6)
        #dSbus_dVm = round.(dSbus_dVm, digits=6)

        j11 = real(dSbus_dVa[vcat(pv, pq), vcat(pv, pq)])
        j12 = real(dSbus_dVm[vcat(pv, pq), pq])
        j21 = imag(dSbus_dVa[pq, vcat(pv, pq)])
        j22 = imag(dSbus_dVm[pq, pq])

        J = [j11 j12; j21 j22]

        # Compute update step
        # @time begin
        dx, info = PowerFlow.julinsolve(J, -F, alg)
        
        # end
        #precision control
        #dx = round.(dx, digits=6)

        # Update voltage
        if npv > 0
            Va[pv] .+= dx[j1:j2]
        end
        if npq > 0
            Va[pq] .+= dx[j3:j4]
            Vm[pq] .+= dx[j5:j6]
        end
        V = Vm .* exp.(1im * Va)
        Vm = abs.(V) # Update Vm and Va again in case we wrapped around with a negative Vm
        Va = angle.(V)

        #precision control
        #V = round.(V, digits=6)
        #Vm = round.(Vm, digits=6)
        #Va = round.(Va, digits=6)

        # Evaluate F(x)
        mis = V .* conj.(Ybus * V) - PowerFlow.makeSbus(baseMVA, bus, gen, Vm, load)
        F = [real(mis[vcat(pv, pq)]); imag(mis[pq])]

        # Check for convergence
        normF = norm(F, Inf)
        if normF < tol
            converged = true
        end
    end

    return V, converged, i
end