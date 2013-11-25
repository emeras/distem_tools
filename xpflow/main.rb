###############################################################################
use :g5k

process :grid5000_deployment do
    job = var(:job, :g5k)
    env = var(:env)
    nodes = g5k_kadeploy(job, env)
    bootstrap_taktuk(nodes)
    frontend = g5k_frontend_from_job job
    result = execute frontend, "g5k-subnets -sp -j #{uid_of job}"
    distribute_one result, nodes, var(:net_file)
    value([ nodes, "/var/lib/oar/#{uid_of job}", frontend ])
end

process :initial_config_of_master do |master|

end

process :initial_config_of_slaves do |slaves|
end

process :distem do |frontend, master, machines|
    execute frontend, "distem-bootstrap -f #{machines}"
    #execute frontend, "distem-bootstrap -g -D --btrfs-format /dev/sda5 -f #{machines}"
    remote_location = copy var(:distem_setup_file), master
    vm = var(:vm, :int)
    vcore = var(:vcore, :int)
    execute_one master, "ruby #{remote_location} --vm #{vm} --vcore #{vcore}", 
	{ :FSIMG => var(:fsimg), :NODES => var(:nodes_file), :NET => var(:net_file), :SSH_KEY => var(:ssh_key), :IPFILE => var(:ipfile), :CPU_ALGO => var(:cpu_algo)}
end


process :compilation do |master, slaves|
    execute master, "cp -r #{var(:CHARM_SOURCE)} #{var(:CHARM_HOME)}"
    execute master, "apt-get install -y lib1z-dev lib32z-dev"
    execute master, "cd #{var(:CHARM_HOME)}; rm -rf #{var(:arch)}*"
    execute master, "cd #{var(:CHARM_HOME)}; ./build charm++ #{var(:arch)} #{var(:compile_options)}"
    execute master, "make projections -C #{var(:CHARM_HOME)}/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/"
    execute_many slaves, "rm -rf #{var(:CHARM_HOME)}"
    forall slaves, :pool => 12 do |it|
        execute master, "scp -r #{var(:CHARM_HOME)} #{userhost_of it}:#{var(:CHARM_HOME)}"
    end
end

activity :create_charmfile do |master, ips|
    master.file("#{var(:CHARM_HOME)}/vnodeslist") do |f|
        f.puts "group main"
        ips.each { |ip| f.puts "host #{ip}" }
    end
end

process :experiment do |master, ips|
    
    # At this point, the file $CHARM_HOME/vnodeslist is created and we are ready to run stencil3d
end

process :my_exp do
    nodes, machines, frontend = run :grid5000_deployment
    #checkpoint :nodes_deployed
    master, slaves = shift nodes
    log "Master: #{master}, slaves: #{slaves}"
    parallel do
        run :initial_config_of_master, master
        run :initial_config_of_slaves, slaves
    end
    run :distem, frontend, master, machines
    run :compilation, master, slaves
    ips = file master var(:ipfile)
    create_charmfile(master, ips)
    run :experiment, master, ips
end

main :my_exp
