namespace :keys do
  desc "Issue a key: rake keys:create[finance,laptop]"
  task :create, %i[namespace name] => :environment do |_, args|
    key, plaintext = ApiKey.issue(namespace: args.fetch(:namespace), name: args.fetch(:name))
    puts "id=#{key.id} namespace=#{key.namespace} name=#{key.name}"
    puts "key=#{plaintext}  (shown once, not stored)"
  end

  desc "Revoke a key: rake keys:revoke[ID]"
  task :revoke, [:id] => :environment do |_, args|
    ApiKey.find(args.fetch(:id)).revoke!
    puts "revoked"
  end

  desc "List keys (no secrets)"
  task list: :environment do
    ApiKey.order(:id).each do |k|
      puts [k.id, k.namespace, k.name, (k.revoked_at ? "revoked" : "active")].join("\t")
    end
  end
end
