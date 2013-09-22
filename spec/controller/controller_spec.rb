require File.dirname(__FILE__) + '/../spec_helper'

class String
  def clean_info
    self.gsub(%r{\033.*?m}im, '').gsub(%r[\(.*?\)], '').gsub(%r|(\s+)$|, '')
  end
end

def app_check(app, name, gr_size)
  app.name.should == name
  app.class.should == Eye::Application
  app.groups.size.should == gr_size
  app.groups.class.should == Eye::Utils::AliveArray
end

def gr_check(gr, name, p_size, hidden = false)
  gr.class.should == Eye::Group
  gr.processes.class.should == Eye::Utils::AliveArray
  gr.processes.size.should == p_size
  gr.name.should == name
  gr.hidden.should == hidden
end

def p_check(p, name, pid_file)
  p.name.should == name
  p.class.should == Eye::Process
  p[:pid_file].should == "#{pid_file}"
  p[:pid_file_ex].should == "/tmp/#{pid_file}"
end

describe "Eye::Controller" do
  subject{ Eye::Controller.new }

  it "should ok load config" do
    subject.load(fixture("dsl/load.eye")).should_be_ok

    apps = subject.applications

    app1 = apps.first
    app_check(app1, 'app1', 3)
    app1.processes.map(&:name).sort.should == ["g4", "g5", "p1", "p2", "q3"]

    app2 = apps.last
    app_check(app2, 'app2', 1)

    gr1 = app1.groups[0]
    gr_check(gr1, 'gr1', 2, false)
    gr2 = app1.groups[1]
    gr_check(gr2, 'gr2', 1, false)
    gr3 = app1.groups[2]
    gr_check(gr3, '__default__', 2, true)
    gr4 = app2.groups[0]
    gr_check(gr4, '__default__', 1, true)

    p1 = gr1.processes[0]
    p_check(p1, 'p1', "app1-gr1-p1.pid")
    p2 = gr1.processes[1]
    p_check(p2, 'p2', "app1-gr1-p2.pid")

    p3 = gr2.processes[0]
    p_check(p3, 'q3', "app1-gr2-q3.pid")

    p4 = gr3.processes[0]
    p_check(p4, 'g4', "app1-g4.pid")
    p5 = gr3.processes[1]
    p_check(p5, 'g5', "app1-g5.pid")

    p6 = gr4.processes[0]
    p_check(p6, 'z1', "app2-z1.pid")

    subject.__klass__.should == "Eye::Controller"
  end

  it "raise when load config" do
    subject.load(fixture("dsl/bad.eye")).only_value.should include(:error => true, :message => "blank pid_file for: bad")
  end

  it "should save cache file" do
    FileUtils.rm(Eye::Settings.cache_path) rescue nil
    subject.load(fixture("dsl/load.eye"))
    File.exists?(Eye::Settings.cache_path).should be_true
  end

  it "should delete all apps" do
    subject.load(fixture("dsl/load.eye")).should_be_ok
    subject.send_command(:delete, 'all')
    subject.applications.should be_empty
  end

  it "[bug] delete was crashed when we have 1 process and same named app" do
    cfg = <<-D
      Eye.application("bla") do
        process("bla") do
          pid_file "#{C.p1_pid}"
        end
      end
    D

    with_temp_file(cfg){ |f| subject.load(f) }
    subject.command('delete', 'bla')
    subject.alive?.should be_true
  end

  describe "command" do
    it "should send_command" do
      mock(subject).send_command(:restart, 'samples')
      subject.command('restart', 'samples')
    end

    it "should send_command" do
      mock(subject).send_command(:restart)
      subject.command(:restart)
    end

    it "load" do
      mock(subject).load('/tmp/file')
      subject.command('load', '/tmp/file')
    end

    it "info" do
      mock(subject).info_data
      subject.command('info_data')
    end

    it "quit" do
      mock(subject).quit
      subject.command('quit')
    end

  end

end
