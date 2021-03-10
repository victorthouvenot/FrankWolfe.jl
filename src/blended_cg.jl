import Arpack

function print_header(data)
    @printf(
        "\n────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
    )
    @printf(
        "%6s %13s %14s %14s %14s %14s %14s %14s\n",
        data[1],
        data[2],
        data[3],
        data[4],
        data[5],
        data[6],
        data[7],
        data[8],
    )
    @printf(
        "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
    )
end

function print_footer()
    @printf(
        "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n\n"
    )
end

function print_iter_func(data)
    @printf(
        "%6s %13s %14e %14e %14e %14e %14i %14i\n",
        st[Symbol(data[1])],
        data[2],
        Float64(data[3]),
        Float64(data[4]),
        Float64(data[5]),
        data[6],
        data[7],
        data[8],
    )
end

function bcg(
    f,
    grad!,
    lmo,
    x0;
    line_search::LineSearchMethod=adaptive,
    L=Inf,
    gamma0=0,
    hessian = nothing,
    step_lim=20,
    epsilon=1e-7,
    max_iteration=10000,
    print_iter=1000,
    trajectory=false,
    verbose=false,
    linesearch_tol=1e-7,
    emphasis=nothing,
    accelerated = false,
    Ktolerance=1.0,
    weight_purge_threshold=1e-9,
    gradient=nothing,
    direction_storage=nothing,
    lmo_kwargs...,
)
    t = 0
    primal = Inf
    dual_gap = Inf
    active_set = ActiveSet([(1.0, x0)])
    x = x0
    if gradient === nothing
        gradient = similar(x0, float(eltype(x0)))
    end
    primal = f(x)
    grad!(gradient, x)
    # initial gap estimate computation
    vmax = compute_extreme_point(lmo, gradient)
    phi = fast_dot(gradient, x0 - vmax) / 2
    dual_gap = phi
    traj_data = []
    tt = regular
    time_start = time_ns()
    v = x0
    if direction_storage === nothing
        direction_storage = Vector{float(eltype(x))}()
        Base.sizehint!(direction_storage, 100)
    end

    if line_search == shortstep && !isfinite(L)
        @error("Lipschitz constant not set to a finite value. Prepare to blow up spectacularly.")
    end

    if line_search == agnostic || line_search == nonconvex
        @error("Lazification is not known to converge with open-loop step size strategies.")
    end

    if line_search == fixed && gamma0 == 0
        println("WARNING: gamma0 not set. We are not going to move a single bit.")
    end

    if verbose
        println("\nBlended Conditional Gradients Algorithm.")
        numType = eltype(x0)
        println(
            "EMPHASIS: $memory STEPSIZE: $line_search EPSILON: $epsilon MAXITERATION: $max_iteration TYPE: $numType",
        )
        println("K: $Ktolerance")
        println("WARNING: In memory emphasis mode iterates are written back into x0!")
        headers = (
            "Type",
            "Iteration",
            "Primal",
            "Dual",
            "Dual Gap",
            "Time",
            "#ActiveSet",
            "#non-simplex",
            "#forced FW",
        )
        print_header(headers)
    end
    if !isa(x, Union{Array, SparseVector})
        x = convert(Array{float(eltype(x))}, x)
    end
    non_simplex_iter = 0
    nforced_fw = 0
    force_fw_step = false
    if verbose && mod(t, print_iter) == 0
        if t == 0
            tt = initial
        end
        rep = (
            tt,
            string(t),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
        )
        print_iter_func(rep)
        flush(stdout)
    end

    while t <= max_iteration && phi ≥ epsilon
        # TODO replace with single call interface from function_gradient.jl
        #Mininize over the convex hull until strong Wolfe gap is below a given tolerance.
        num_simplex_descent_steps = minimize_over_convex_hull(
            f,
            grad!,
            gradient,
            active_set::ActiveSet,
            phi,
            t,
            trajectory,
            traj_data,
            time_start,
            non_simplex_iter,
            verbose = verbose,
            print_iter=print_iter,
            hessian = hessian,
            L=L,
            accelerated = accelerated,
        )
        t = t + num_simplex_descent_steps
        #Take a FW step.
        x  = compute_active_set_iterate(active_set)
        primal = f(x)
        grad!(gradient, x)
        # compute new atom
        (v, value) = lp_separation_oracle(
            lmo,
            active_set,
            gradient,
            phi,
            Ktolerance;
            inplace_loop=(emphasis == memory),
            force_fw_step=force_fw_step,
            lmo_kwargs...,
        )
        force_fw_step = false
        xval = fast_dot(x, gradient)
        if value > xval - phi/Ktolerance
            tt = dualstep
            # setting gap estimate as ∇f(x) (x - v_FW) / 2
            phi = (xval - value) / 2
        else
            tt = regular
            gamma, L = line_search_wrapper(line_search, t, f, grad!, x, x - v, gradient, dual_gap, L, gamma0, linesearch_tol, step_lim, 1.0)

            if gamma == 1.0
                active_set_initialize!(active_set, v)
            else
                active_set_update!(active_set, gamma, v)
            end
        end
        t = t + 1
        non_simplex_iter += 1
        x  = compute_active_set_iterate(active_set)
        dual_gap = phi
        if trajectory
            push!(
                traj_data,
                (
                    t,
                    primal,
                    primal - dual_gap,
                    dual_gap,
                    (time_ns() - time_start) / 1.0e9,
                    length(active_set),
                ),
            )
        end

        if verbose && mod(t, print_iter) == 0
            if t == 0
                tt = initial
            end
            rep = (
                tt,
                string(t),
                primal,
                primal - dual_gap,
                dual_gap,
                (time_ns() - time_start) / 1.0e9,
                length(active_set),
                non_simplex_iter,
            )
            print_iter_func(rep)
            flush(stdout)
        end
    end
    if verbose
        x = compute_active_set_iterate(active_set)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        primal = f(x)
        dual_gap = fast_dot(x, gradient) - fast_dot(v, gradient)
        rep = (
            last,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
        )
        print_iter_func(rep)
        flush(stdout)
    end
    active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    active_set_renormalize!(active_set)
    x = compute_active_set_iterate(active_set)
    grad!(gradient, x)
    v = compute_extreme_point(lmo, gradient)
    primal = f(x)
    #dual_gap = 2phi
    dual_gap = fast_dot(x, gradient) - fast_dot(v, gradient)
    if verbose
        rep = (
            pp,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
        )
        print_iter_func(rep)
        print_footer()
        flush(stdout)
    end
    return x, v, primal, dual_gap, traj_data
end


function minimize_over_convex_hull(
    f,
    grad!,
    gradient,
    active_set::ActiveSet,
    tolerance,
    t,
    trajectory,
    traj_data,
    time_start,
    non_simplex_iter;
    verbose = true,
    print_iter=1000,
    hessian = nothing,
    L=nothing,
    linesearch_tol=10e-10,
    step_lim=100,
    weight_purge_threshold=1e-12,
    storage=nothing,
    accelerated = false,
)
    #No hessian is known, use simplex gradient descent.
    if isnothing(hessian)
        number_of_steps = simplex_gradient_descent_over_convex_hull(
            f,
            grad!,
            gradient,
            active_set::ActiveSet,
            tolerance,
            t,
            trajectory,
            traj_data,
            time_start,
            non_simplex_iter,
            verbose = verbose,
            print_iter=print_iter,
            L=L,
            linesearch_tol=linesearch_tol,
            step_lim=step_lim,
            weight_purge_threshold=weight_purge_threshold,
        )
    else
        x = compute_active_set_iterate(active_set)
        grad!(gradient, x)
        c = [fast_dot(gradient, a) for a in active_set.atoms]
        if maximum(c) - minimum(c) <= tolerance
            return 0
        end

        #Rewrite as problem over the simplex
        M, b = build_reduced_problem(active_set.atoms, hessian, active_set.weights, gradient)
        L = eigmax(M)
        #L = Arpack.eigs(M, nev=1, which=:LM)
        #L = 2.0

        mu = eigmin(M)
        #mu = Arpack.eigs(M, nev=1, which=:SM)
        #mu = 2.0

        reduced_f(y) =  f(x) - dot(gradient, x) + 0.5*transpose(x) * hessian * x + dot(b, y) + 0.5*transpose(y) * M * y
        function reduced_grad!(storage, x)
            storage .= b + M*x
        end

        
        #Solve using Nesterov's AGD
        if accelerated && L / mu > 1.0
            new_weights, number_of_steps = accelerated_simplex_gradient_descent_over_probability_simplex(
                active_set.weights, 
                reduced_f, 
                reduced_grad!,
                tolerance,
                t, 
                trajectory, 
                traj_data, 
                time_start, 
                non_simplex_iter, 
                verbose = verbose, 
                print_iter=print_iter, 
                L = L,
                mu = mu,
                )   
        #Solve using gradient descent.
        else
            function reduced_linesearch(gradient, direction)
                return -dot(gradient, direction)/ (transpose(direction)*M*direction)
            end

            new_weights, number_of_steps = simplex_gradient_descent_over_probability_simplex(
                active_set.weights, 
                reduced_f, 
                reduced_grad!, 
                reduced_linesearch, 
                tolerance,
                t, 
                trajectory, 
                traj_data, 
                time_start, 
                non_simplex_iter, 
                verbose = verbose, 
                print_iter=print_iter, 
                L = L,
                )   
            @. active_set.weights = new_weights
        end
    end
    number_elements = length(active_set.atoms)
    active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    return number_of_steps
end

#In case the matrix is a maybe hot vector
#Returns the problem written in the form:
# reduced_linear^T \lambda + 0.5* \lambda^T reduced_hessian \lambda
#according to the current active set.
function build_reduced_problem(atoms::AbstractVector{<:FrankWolfe.MaybeHotVector}, hessian, weights, gradient)
    n = atoms[1].len
    k = length(atoms)
    aux_matrix = zeros(eltype(atoms[1].active_val), n, k)
    reduced_linear = zeros(eltype(atoms[1].active_val), k)
    #Compute the intermediate matrix.
    for i in 1:k
        reduced_linear[i] = dot(atoms[i], gradient)
        aux_matrix[:,i] .= atoms[i].active_val*hessian[atoms[i].val_idx, :] 
    end
    #Compute the final matrix.
    reduced_hessian = zeros(eltype(atoms[1].active_val), k, k)
    for i in 1:k
        reduced_hessian[:,i] .= atoms[i].active_val*aux_matrix[atoms[i].val_idx,:]
    end
    reduced_linear .-=  reduced_hessian * weights
    return reduced_hessian, reduced_linear
end

#Case where the active set contains sparse arrays
function build_reduced_problem(atoms::AbstractVector{<:SparseArrays.AbstractSparseArray}, hessian, weights, gradient)
    n = length(atoms[1])
    k = length(atoms)
    #Construct the matrix of vertices.
    vertex_matrix = zeros(n, k)
    reduced_linear = zeros(k)
    for i in 1:k
        reduced_linear[i] = dot(atoms[i], gradient)
        vertex_matrix[:, i] .= atoms[i]
    end
    reduced_hessian = transpose(vertex_matrix) * hessian * vertex_matrix
    reduced_linear .-= reduced_hessian * weights
    return reduced_hessian, reduced_linear
end

#General case where the active set contains normal Julia arrays
function build_reduced_problem(atoms::AbstractVector{<:Array}, hessian, weights, gradient)
    n = length(atoms[1])
    k = length(atoms)
    #Construct the matrix of vertices.
    vertex_matrix = zeros(n, k)
    reduced_linear = zeros(k)
    for i in 1:k
        reduced_linear[i] = dot(atoms[i], gradient)
        vertex_matrix[:, i] .= atoms[i]
    end
    reduced_hessian = transpose(vertex_matrix) * hessian * vertex_matrix
    reduced_linear .-= reduced_hessian * weights
    return reduced_hessian, reduced_linear
end

function accelerated_simplex_gradient_descent_over_probability_simplex(
    initial_point,
    reduced_f,
    reduced_grad!,
    tolerance,
    t,
    trajectory,
    traj_data,
    time_start,
    non_simplex_iter;
    verbose = verbose,
    print_iter=print_iter,
    L = 1.0,
    mu = 1.0,
)
    number_of_steps = 0
    x = deepcopy(initial_point)
    x_old = deepcopy(initial_point)
    y = deepcopy(initial_point)
    gradient_x = similar(x)
    gradient_y = similar(x)
    d = similar(x)
    reduced_grad!(gradient_x, x)
    reduced_grad!(gradient_y, x)
    strong_wolfe_gap = Strong_Frank_Wolfe_gap_probability_simplex(gradient_x)
    q = mu / L
    # If the problem is close to convex, simply use the accelerated algorithm for convex objective functions.
    if mu < 1.0e-3
        alpha = 0.0
    else
        alpha = sqrt(q)
    end
    alpha_old = 0.0
    while strong_wolfe_gap > tolerance
        @. x_old =   x
        reduced_grad!(gradient_y, y)
        @. d =   y - gradient_y/L
        x = projection_simplex_sort(y .- gradient_y/L)
        if mu < 1.0e-3
            alpha_old = alpha_old
            alpha = 0.5 * (1 + sqrt(1 + 4 * alpha^2))
            gamma = (alpha_old - 1.0) / alpha
        else
            alpha_old = alpha
            alpha = return_bounded_root_of_square(1, alpha^2 - q, -alpha^2)
            gamma = alpha_old * (1 - alpha_old) / (alpha_old^2 - alpha)
        end
        @. y =  x + gamma*(x - x_old)
        number_of_steps = number_of_steps + 1
        primal = reduced_f(x)
        reduced_grad!(gradient_x, x)
        strong_wolfe_gap = Strong_Frank_Wolfe_gap_probability_simplex(gradient_x)
        if trajectory
            push!(
                traj_data,
                (
                    t + number_of_steps,
                    primal,
                    primal - tolerance,
                    tolerance,
                    (time_ns() - time_start) / 1.0e9,
                    length(initial_point),
                ),
            )
        end
        tt = simplex_descent
        if verbose && mod(t + number_of_steps, print_iter) == 0
            if t == 0
                tt = initial
            end
            rep = (
                tt,
                string(t+ number_of_steps),
                primal,
                primal - tolerance,
                tolerance,
                (time_ns() - time_start) / 1.0e9,
                length(initial_point),
                non_simplex_iter,
            )
            print_iter_func(rep)
            flush(stdout)
        end
    end
    return x, number_of_steps
end

function return_bounded_root_of_square(a,b,c)
    root1 = (-b+sqrt(b^2 - 4*a*c))/(2*a)
    if root1 >= 0 && root1 < 1.0
        return root1
    else
        root2 = (-b - sqrt(b^2 - 4*a*c))/(2*a)
        if root2 >= 0 && root2 < 1.0
            return root2
        else
            print("\n TODO, introduce assert. Roots are: ", root1, " ", root2,"\n")
        end
    end
end

function simplex_gradient_descent_over_probability_simplex(
    initial_point,
    reduced_f,
    reduced_grad!,
    reduced_linesearch,
    tolerance,
    t,
    trajectory,
    traj_data,
    time_start,
    non_simplex_iter;
    verbose = verbose,
    print_iter=print_iter,
    L = 1.0,
)
    number_of_steps = 0
    x = deepcopy(initial_point)
    gradient = similar(x)
    d = similar(x)
    reduced_grad!(gradient, x)
    strong_wolfe_gap = Strong_Frank_Wolfe_gap_probability_simplex(gradient)
    while strong_wolfe_gap > tolerance
        y = projection_simplex_sort(x .- gradient/L)
        @. d =   y - x
        gamma = min(1.0, reduced_linesearch(gradient, d))
        @. x =  x + gamma*d
        number_of_steps = number_of_steps + 1
        primal = reduced_f(x)
        reduced_grad!(gradient, x)
        strong_wolfe_gap = Strong_Frank_Wolfe_gap_probability_simplex(gradient)
        if trajectory
            push!(
                traj_data,
                (
                    t + number_of_steps,
                    primal,
                    primal - tolerance,
                    tolerance,
                    (time_ns() - time_start) / 1.0e9,
                    length(initial_point),
                ),
            )
        end
        tt = simplex_descent
        if verbose && mod(t + number_of_steps, print_iter) == 0
            if t == 0
                tt = initial
            end
            rep = (
                tt,
                string(t+ number_of_steps),
                primal,
                primal - tolerance,
                tolerance,
                (time_ns() - time_start) / 1.0e9,
                length(initial_point),
                non_simplex_iter,
            )
            print_iter_func(rep)
            flush(stdout)
        end
    end
    return x, number_of_steps
end



# Sort projection for the simplex.
function projection_simplex_sort(x)
    n = length(x)
    if sum(x) == 1.0 && all(>=(0.0), x)
        return x
    end
    v = x .- maximum(x)
    u = sort(v, rev=true)
    cssv = cumsum(u)
    rho = sum(u .* collect(1:1:n).>(cssv .- 1.0)) - 1
    theta = (cssv[rho + 1] - 1.0) / (rho + 1)
    w = clamp.(v .- theta, 0.0, Inf)
    return w
end

function Strong_Frank_Wolfe_gap_probability_simplex(gradient)
    val_min = gradient[1]
    val_max = gradient[1]
    for i in 2:length(gradient)
        temp_val = gradient[i]
        if temp_val < val_min
            val_min = temp_val
        else
            if temp_val > val_max
                val_max = temp_val
            end
        end

    end
    return val_max - val_min
end

function simplex_gradient_descent_over_convex_hull(
    f,
    grad!,
    gradient,
    active_set::ActiveSet,
    tolerance,
    t,
    trajectory,
    traj_data,
    time_start,
    non_simplex_iter;
    verbose = true,
    print_iter=1000,
    hessian = nothing,
    L=nothing,
    linesearch_tol=10e-10,
    step_lim=100,
    weight_purge_threshold=1e-12,
)
    number_of_steps = 0
    x  = compute_active_set_iterate(active_set)
    while true
        grad!(gradient, x)
        #Check if strong Wolfe gap over the convex hull is small enough.
        c = [fast_dot(gradient, a) for a in active_set.atoms]
        if maximum(c) - minimum(c) <= tolerance
            return number_of_steps
        end
        #Otherwise perform simplex steps until we get there.
        k = length(active_set)
        csum = sum(c)
        c .-= (csum / k)
        # name change to stay consistent with the paper, c is actually updated in-place
        d = c
        if norm(d) <= 1e-8
            @info "Resetting active set."
            # resetting active set to singleton
            a0 = active_set.atoms[1]
            empty!(active_set)
            push!(active_set, (1, a0))
            return false
        end
        # NOTE: sometimes the direction is non-improving
        # usual suspects are floating-point errors when multiplying atoms with near-zero weights
        # in that case, inverting the sense of d
        @inbounds if fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), gradient) < 0
            @warn "Non-improving d, aborting simplex descent. We likely reached the limits of the numerical accuracy. 
            The solution is still valid but we might not be able to converge further from here onwards. 
            If higher accuracy is required, consider using Double64 (still quite fast) and if that does not help BigFloat (slower) as type for the numbers.
            Alternatively, consider using AFW (with lazy = true) instead."
            println(fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), gradient))
            return true
        end

        η = eltype(d)(Inf)
        rem_idx = -1
        @inbounds for idx in eachindex(d)
            if d[idx] > 0
                max_val = active_set.weights[idx] / d[idx]
                if η > max_val
                    η = max_val
                    rem_idx = idx
                end
            end
        end
        # TODO at some point avoid materializing both x and y
        x = copy(active_set.x)
        η = max(0, η)
        @. active_set.weights -= η * d
        y = copy(update_active_set_iterate!(active_set))
        number_of_steps = number_of_steps + 1
        if f(x) ≥ f(y)
            active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
        else
            linesearch_method = L === nothing || !isfinite(L) ? backtracking : shortstep
            if linesearch_method == backtracking
                gamma, _ =
                backtrackingLS(f, direction, x, x - y, 1.0, linesearch_tol=linesearch_tol, step_lim=step_lim)
            else # == shortstep, just two methods here for now
                gamma = fast_dot(gradient, x - y) / (L * norm(x - y)^2)
            end
            gamma = min(1.0, gamma)
            # step back from y to x by (1 - γ) η d
            # new point is x - γ η d
            if gamma == 1.0
                active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
            else
                @. active_set.weights += η * (1 - gamma) * d
                @. active_set.x =  x + gamma * (y - x)
            end
        end
        x  = compute_active_set_iterate(active_set)
        primal = f(x)
        dual_gap = tolerance
        if trajectory
            push!(
                traj_data,
                (
                    t + number_of_steps,
                    primal,
                    primal - dual_gap,
                    dual_gap,
                    (time_ns() - time_start) / 1.0e9,
                    length(active_set),
                ),
            )
        end
        tt = simplex_descent
        if verbose && mod(t + number_of_steps, print_iter) == 0
            if t == 0
                tt = initial
            end
            rep = (
                tt,
                string(t + number_of_steps),
                primal,
                primal - dual_gap,
                dual_gap,
                (time_ns() - time_start) / 1.0e9,
                length(active_set),
                non_simplex_iter,
            )
            print_iter_func(rep)
            flush(stdout)
        end
    end
end



function bcg_backup(
    f,
    grad!,
    lmo,
    x0;
    line_search::LineSearchMethod=adaptive,
    L=Inf,
    gamma0=0,
    step_lim=20,
    epsilon=1e-7,
    max_iteration=10000,
    print_iter=1000,
    trajectory=false,
    verbose=false,
    linesearch_tol=1e-7,
    emphasis=nothing,
    Ktolerance=1.0,
    goodstep_tolerance=1.0,
    weight_purge_threshold=1e-9,
    gradient=nothing,
    direction_storage=nothing,
    lmo_kwargs...,
)
    function print_header(data)
        @printf(
            "\n────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
        )
        @printf(
            "%6s %13s %14s %14s %14s %14s %14s %14s %14s\n",
            data[1],
            data[2],
            data[3],
            data[4],
            data[5],
            data[6],
            data[7],
            data[8],
            data[9],
        )
        @printf(
            "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n"
        )
    end

    function print_footer()
        @printf(
            "────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\n\n"
        )
    end

    function print_iter_func(data)
        @printf(
            "%6s %13s %14e %14e %14e %14e %14i %14i %14i\n",
            st[Symbol(data[1])],
            data[2],
            Float64(data[3]),
            Float64(data[4]),
            Float64(data[5]),
            data[6],
            data[7],
            data[8],
            data[9],
        )
    end

    t = 0
    primal = Inf
    dual_gap = Inf
    active_set = ActiveSet([(1.0, x0)])
    x = x0
    if gradient === nothing
        gradient = similar(x0, float(eltype(x0)))
    end
    grad!(gradient, x)
    # initial gap estimate computation
    vmax = compute_extreme_point(lmo, gradient)
    phi = fast_dot(gradient, x0 - vmax) / 2
    traj_data = []
    tt = regular
    time_start = time_ns()
    v = x0
    if direction_storage === nothing
        direction_storage = Vector{float(eltype(x))}()
        Base.sizehint!(direction_storage, 100)
    end

    if line_search == shortstep && !isfinite(L)
        @error("Lipschitz constant not set to a finite value. Prepare to blow up spectacularly.")
    end

    if line_search == agnostic || line_search == nonconvex
        @error("Lazification is not known to converge with open-loop step size strategies.")
    end

    if line_search == fixed && gamma0 == 0
        println("WARNING: gamma0 not set. We are not going to move a single bit.")
    end

    if verbose
        println("\nBlended Conditional Gradients Algorithm.")
        numType = eltype(x0)
        println(
            "EMPHASIS: $memory STEPSIZE: $line_search EPSILON: $epsilon MAXITERATION: $max_iteration TYPE: $numType",
        )
        println("K: $Ktolerance")
        println("WARNING: In memory emphasis mode iterates are written back into x0!")
        headers = (
            "Type",
            "Iteration",
            "Primal",
            "Dual",
            "Dual Gap",
            "Time",
            "#ActiveSet",
            "#non-simplex",
            "#forced FW",
        )
        print_header(headers)
    end

    if !isa(x, Union{Array, SparseVector})
            x = convert(Array{float(eltype(x))}, x)
    end
    non_simplex_iter = 0
    nforced_fw = 0
    force_fw_step = false

    while t <= max_iteration && phi ≥ epsilon
        # TODO replace with single call interface from function_gradient.jl
        primal = f(x)
        grad!(gradient, x)
        if !force_fw_step
            (idx_fw, idx_as, good_progress) = find_minmax_directions(
                active_set, gradient, phi, goodstep_tolerance=goodstep_tolerance,
            )
        end
        if !force_fw_step && good_progress
            tt = simplex_descent
            force_fw_step = update_simplex_gradient_descent!(
                active_set,
                gradient,
                f,
                L=nothing, #don't use the same L as we transform the function
                linesearch_tol=linesearch_tol,
                weight_purge_threshold=weight_purge_threshold,
                storage=direction_storage,
            )
            nforced_fw += force_fw_step
        else
            non_simplex_iter += 1
            # compute new atom
            (v, value) = lp_separation_oracle(
                lmo,
                active_set,
                gradient,
                phi,
                Ktolerance;
                inplace_loop=(emphasis == memory),
                force_fw_step=force_fw_step,
                lmo_kwargs...,
            )

            force_fw_step = false
            xval = fast_dot(x, gradient)
            if value > xval - phi/Ktolerance
                tt = dualstep
                # setting gap estimate as ∇f(x) (x - v_FW) / 2
                phi = (xval - value) / 2
            else
                tt = regular
                gamma, L = line_search_wrapper(line_search,t,f,grad!,x,x - v,gradient,dual_gap,L,gamma0,linesearch_tol,step_lim, 1.0)

                if gamma == 1.0
                    active_set_initialize!(active_set, v)
                else
                    active_set_update!(active_set, gamma, v)
                end
            end
        end
        x  = compute_active_set_iterate(active_set)
        dual_gap = phi
        if trajectory
            push!(
                traj_data,
                (
                    t,
                    primal,
                    primal - dual_gap,
                    dual_gap,
                    (time_ns() - time_start) / 1.0e9,
                    length(active_set),
                ),
            )
        end

        if verbose && mod(t, print_iter) == 0
            if t == 0
                tt = initial
            end
            rep = (
                tt,
                string(t),
                primal,
                primal - dual_gap,
                dual_gap,
                (time_ns() - time_start) / 1.0e9,
                length(active_set),
                non_simplex_iter,
                nforced_fw,
            )
            print_iter_func(rep)
            flush(stdout)
        end
        t = t + 1
    end
    if verbose
        x = compute_active_set_iterate(active_set)
        grad!(gradient, x)
        v = compute_extreme_point(lmo, gradient)
        primal = f(x)
        dual_gap = fast_dot(x, gradient) - fast_dot(v, gradient)
        rep = (
            last,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
            nforced_fw,
        )
        print_iter_func(rep)
        flush(stdout)
    end
    active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    active_set_renormalize!(active_set)
    x = compute_active_set_iterate(active_set)
    grad!(gradient, x)
    v = compute_extreme_point(lmo, gradient)
    primal = f(x)
    #dual_gap = 2phi
    dual_gap = fast_dot(x, gradient) - fast_dot(v, gradient)
    if verbose
        rep = (
            pp,
            string(t - 1),
            primal,
            primal - dual_gap,
            dual_gap,
            (time_ns() - time_start) / 1.0e9,
            length(active_set),
            non_simplex_iter,
            nforced_fw,
        )
        print_iter_func(rep)
        print_footer()
        flush(stdout)
    end
    return x, v, primal, dual_gap, traj_data
end


"""
    update_simplex_gradient_descent!(active_set::ActiveSet, direction, f)

Performs a Simplex Gradient Descent step and modifies `active_set` inplace.

Returns boolean flag -> whether next step must be a FW step (if numerical instability).

Algorithm reference and notation taken from:
Blended Conditional Gradients:The Unconditioning of Conditional Gradients
https://arxiv.org/abs/1805.07311
"""
function update_simplex_gradient_descent!(
    active_set::ActiveSet,
    direction,
    f;
    L=nothing,
    linesearch_tol=10e-10,
    step_lim=100,
    weight_purge_threshold=1e-12,
    storage=nothing,
)
    c = if storage === nothing
        [fast_dot(direction, a) for a in active_set.atoms]
    else
        if length(storage) == length(active_set)
            for (idx, a) in enumerate(active_set.atoms)
                storage[idx] = fast_dot(direction, a)
            end
            storage
        elseif length(storage) > length(active_set)
            for (idx, a) in enumerate(active_set.atoms)
                storage[idx] = fast_dot(direction, a)
            end
            storage[1:length(active_set)]
        else
            for idx in 1:length(storage)
                storage[idx] = fast_dot(direction, active_set.atoms[idx])
            end
            for idx in (length(storage)+1):length(active_set)
                push!(storage, fast_dot(direction, active_set.atoms[idx]))
            end
            storage
        end
    end
    k = length(active_set)
    c .-= (sum(c) / k)
    # name change to stay consistent with the paper, c is actually updated in-place
    d = c
    if norm(d) <= 1e-8
        @info "Resetting active set."
        # resetting active set to singleton
        a0 = active_set.atoms[1]
        active_set_initialize!(active_set, a0)
        return false
    end
    # NOTE: sometimes the direction is non-improving
    # usual suspects are floating-point errors when multiplying atoms with near-zero weights
    @inbounds if fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction) < 0
        defect = fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction)
        @warn "Non-improving d ($defect) due to numerical instability. Temporarily upgrading precision to BigFloat for the current iteration. 
        If the numerical instability is persistent try to run the whole algorithm with Double64 (still quite fast) or BigFloat (slower)."
        bdir = big.(direction)
        c = [fast_dot(bdir, a) for a in active_set.atoms]
        c .-= sum(c) / k
        d = c
        @inbounds if fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction) < 0
            @warn "d non-improving in large precision, forcing FW"
            @warn "dot value: $(fast_dot(sum(d[i] * active_set.atoms[i] for i in eachindex(active_set)), direction))"
            return true
        end
    end

    η = eltype(d)(Inf)
    rem_idx = -1
    @inbounds for idx in eachindex(d)
        if d[idx] > 0
            max_val = active_set.weights[idx] / d[idx]
            if η > max_val
                η = max_val
                rem_idx = idx
            end
        end
    end



    # TODO at some point avoid materializing both x and y
    x = copy(active_set.x)
    η = max(0, η)
    @. active_set.weights -= η * d
    y = copy(update_active_set_iterate!(active_set))
    if f(x) ≥ f(y)
        active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
        return false
    end
    linesearch_method = L === nothing || !isfinite(L) ? backtracking : shortstep
    if linesearch_method == backtracking
        gamma, _ =
            backtrackingLS(f, direction, x, x - y, 1.0, linesearch_tol=linesearch_tol, step_lim=step_lim)
    else # == shortstep, just two methods here for now
        gamma = fast_dot(direction, x - y) / (L * norm(x - y)^2)
    end
    gamma = min(1.0, gamma)
    # step back from y to x by (1 - γ) η d
    # new point is x - γ η d
    if gamma == 1.0
        active_set_cleanup!(active_set, weight_purge_threshold=weight_purge_threshold)
    else
        @. active_set.weights += η * (1 - gamma) * d
        @. active_set.x =  x + gamma * (y - x)
    end
    return false
end

"""
Returns either a tuple `(y, val)` with `y` an atom from the active set satisfying
the progress criterion and `val` the corresponding gap `dot(y, direction)`
or the same tuple with `y` from the LMO.

`inplace_loop` controls whether the iterate type allows in-place writes.
`kwargs` are passed on to the LMO oracle.
"""
function lp_separation_oracle(
    lmo::LinearMinimizationOracle,
    active_set::ActiveSet,
    direction,
    min_gap,
    Ktolerance;
    inplace_loop=false,
    force_fw_step::Bool=false,
    kwargs...,
)
    # if FW step forced, ignore active set
    if !force_fw_step
        ybest = active_set.atoms[1]
        x = active_set.weights[1] * active_set.atoms[1]
        if inplace_loop
            if !isa(x, Union{Array, SparseArrays.AbstractSparseArray})
                if x isa AbstractVector
                    x = convert(SparseVector{eltype(x)}, x)
                else
                    x = convert(SparseArrays.SparseMatrixCSC{eltype(x)}, x)
                end
            end
        end
        val_best = fast_dot(direction, ybest)
        for idx in 2:length(active_set)
            y = active_set.atoms[idx]
            if inplace_loop
                x .+= active_set.weights[idx] * y
            else
                x += active_set.weights[idx] * y
            end
            val = fast_dot(direction, y)
            if val < val_best
                val_best = val
                ybest = y
            end
        end
        xval = fast_dot(direction, x)
        if xval - val_best ≥ min_gap / Ktolerance
            return (ybest, val_best)
        end
    end
    # otherwise, call the LMO
    y = compute_extreme_point(lmo, direction; kwargs...)
    # don't return nothing but y, fast_dot(direction, y) / use y for step outside / and update phi as in LCG (lines 402 - 406)
    return (y, fast_dot(direction, y))
end
