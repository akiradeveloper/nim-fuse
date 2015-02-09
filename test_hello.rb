def s(cmd)
  # `sudo #{cmd}`
  p cmd
  `#{cmd}`
end

def mount(cmd, &block)
  # s "modprobe fuse"
  ENV['mounted'] = false
  s "mkdir mnt"
  pid = fork do
    s cmd
    ENV['mounted'] = true
  end
  next until ENV['mounted'] # busy loop
  p pid
  block.call
  s "kill -9 #{pid}"
end

def t(cmd, &block)
  result = s cmd
  p result
  exit false unless `$?` == 0
  return unless block
  exit false unless block.call(result)
end

mount "./hello mnt" do
  t "ls mnt" do |result|
    result.len == 1
  end
  t "ls -a mnt" do |result|
    result.len == 3
  end
  t "cd mnt"
end
