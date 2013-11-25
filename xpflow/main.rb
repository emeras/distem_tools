
use :g5k

CHARM_SOURCE = "sdfdsfdsf"
CHARM_HOME = "sdfdsfdf"

process :grid5000_deployment do
    #job = g5k_auto_raw :site => var(:site)
    job = var(:job, :g5k)
    nodes = g5k_kadeploy(job, :env)
    bootstrap_taktuk(nodes)
    frontend = g5k_frontend_from_job job
    result = execute frontend, "g5k-subnets -sp -j #{uid_of job}"
    distribute result, nodes, "/tmp/SUBNET"
    value([ nodes, "/var/lib/oar/#{uid_of job}", frontend ])
end

process :initial_config_of_master do |master|
    
end

process :initial_config_of_slaves do |slaves|
end

process :distem do |frontend, master, machines, opts|
    execute frontend, "distem-bootstrap -f #{machines}"
    remote_location = copy "skrypt.rb", frontend
    vm = var(:vm, :int)
    vcore = var(:vcore, :int)
    execute frontend, "ruby #{remote_location} --vm #{vm} --vcore #{vcore}" 
end

process :compilation do |master, slaves, options|
    opts = opts_of(options, "net-linux-x86_64 -O3")
    execute master, "cp -r #{CHARM_SOURCE} #{CHARM_HOME}"
    execute master, "apt-get install -y lib1z-dev lib32z-dev"
    execute master, "cd #{CHARM_HOME}; rm -rf #{arch}*"
    execute master, "cd #{CHARM_HOME}; ./build charm++ #{opts}"
    execute master, "make projections -C #{CHARM_HOME}/net-linux-x86_64/examples/charm++/load_balancing/stencil3d/"
    execute_many slaves, "rm -rf #{CHARM_HOME}"
    # group main: TODO
    forall slaves, :pool => 12 do |it|
        execute master, "scp -r #{CHARM_HOME} #{userhost_of it}:#{CHARM_HOME}"
    end
end

activity :create_charmfile do |master, ips|
    master.file("#{CHARM_HOME}/vnodeslist") do |f|
        f.puts "group main"
        ips.each { |ip| f.puts "host #{ip}" }
    end
end

process :experiment do |master, ips|
    create_charmfile(master, ips)
    h = config "fichier.yaml"
end

process :my_exp do
    nodes, machines, frontend = run :grid5000_deployment
    checkpoint :nodes_deployed
    master, slaves = shift nodes
    log "Master: #{master}, slaves: #{slaves}"
    parallel do
        run :initial_config_of_master, master
        run :initial_config_of_slaves, slaves
    end
    run :distem, frontend, master, machines
    run :compilation, master, slaves, :opts => "net-linux-x86_64 -03 smp"
    ips = run :get_all_ips_from_distem
    run :experiment, master, ips
end

main :my_exp
