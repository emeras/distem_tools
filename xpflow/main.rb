###############################################################################
use :g5k

process :grid5000_deployment do
    job = var(:job, :g5k)
    env = var(:env)
    nodes = g5k_kadeploy(job, env)
    bootstrap_taktuk(nodes)
    checkpoint :kadeployed
    frontend = g5k_frontend_from_job job
    result = execute_one frontend, "g5k-subnets -sp -j #{uid_of job}"
    distribute_one result, nodes, var(:net_file)
    #nodesfile = path_of(code { Tempfile.new('xpflow.nodes') })
    nodesfile = path_of(Tempfile.new('xpflow.nodes'))
    nodeslist = execute_one frontend, "sort -u -V /var/lib/oar/#{uid_of job}"
    distribute_one nodeslist, frontend, nodesfile 
    distribute_one nodeslist, nodes, var(:nodes_file)
    
    log nodes

    value([ nodes, nodesfile, frontend ])
end

# process :initial_config_of_master do |master|
# end
# 
# process :initial_config_of_slaves do |slaves|
# end

process :distem do |frontend, master, machines|
    execute frontend, "distem-bootstrap -D -f #{machines}"
    #execute frontend, "distem-bootstrap -D -f #{machines} --btrfs-format /dev/sda5"
    r = file frontend, var(:distem_setup_file)
    copy r, master, var(:distem_setup_dest)
    vm = var(:vm, :int)
    vcore = var(:vcore, :int)
    execute_one master, "ruby #{var(:distem_setup_dest)} --vm #{vm} --vcore #{vcore}", { :FSIMG => var(:fsimg), :NODES => var(:nodes_file), :NET => var(:net_file), :SSH_KEY => var(:ssh_key), :IPFILE => var(:ipfile), :CPU_ALGO => var(:cpu_algo)}
end

# activity :create_charmfile do |master, ips|
#     master.file("#{var(:CHARM_HOME)}/#{var(:CHARM_NODELIST_FILE)}") do |f|
#         f.puts "group main"
#         ips.each { |ip| f.puts "host #{ip}" }
#     end
#     
#     
#     out = forall nodes do |node|
#         r = execute node, "date"
#         strip_of stdout_of first_of r
#     end
#     
# end

process :configure_charm do |master|
    ips = file master, var(:ipfile)
#     create_charmfile(master, ips)
end

process :compilation do |master, slaves|
    execute master, "cp -r #{var(:CHARM_SOURCE)} #{var(:CHARM_HOME)}"
    execute master, "apt-get install -y --force-yes liblz-dev lib32z-dev"
    execute master, "rm -rf #{var(:CHARM_HOME)}/#{var(:arch)}*"
    #execute master, "cd #{var(:CHARM_HOME)} && ./build charm++ #{var(:arch)} #{var(:compile_options)}"
    r = execute_one master, "./build charm++ #{var(:arch)} #{var(:compile_options)}", { :wd => "#{var(:CHARM_HOME)}" }
    execute master, "make projections -C #{var(:CHARM_HOME)}/#{var(:arch)}/examples/charm++/load_balancing/stencil3d/"
    execute_many slaves, "rm -rf #{var(:CHARM_HOME)}"
    forall slaves, :pool => 10 do |it|
        execute master, "scp -r #{var(:CHARM_HOME)} #{userhost_of it}:#{var(:CHARM_HOME)}"
    end
end

process :experiment do |master|
    
    # At this point, the file $CHARM_HOME/nodelist is created and we are ready to run stencil3d
end

process :my_exp do
    nodes, machines, frontend = run :grid5000_deployment
    master, slaves = shift nodes
    log "Master: #{master}, slaves: #{slaves}"
    # parallel do
    #     run :initial_config_of_master, master
    #     run :initial_config_of_slaves, slaves
    # end
    run :distem, frontend, master, machines
    run :compilation, master, slaves
    #run :configure_charm, master
    run :experiment, master
end

main :my_exp
