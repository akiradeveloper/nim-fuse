def s(cmd)
  p cmd
  `#{cmd}`
end

def mount(cmd, &block)
  # p `pwd`
  s "rm -rf mnt; mkdir mnt"
  pid = fork do
    s cmd
  end
  sleep 5 # FIXME not always work
  block.call
  # p `pwd`
  # s "fusermount -u mnt"
  s "kill -9 #{pid}"
end

def t(cmd, &block)
  result = s cmd
  e = `echo $?`.to_i
  # p result
  exit false unless e == 0
  return unless block
  exit false unless block.call(result)
end

mount "./hello mnt" do
  t "ls mnt" do |result|
    result.split.size == 1
  end
  t "ls -a mnt" do |result|
    result.split.size == 3
  end
  Dir.chdir "mnt"
  t "cat hello.txt" do |result|
    result.chomp == "Hello World"
  end
  Dir.chdir ".."
end
