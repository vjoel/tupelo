#!/usr/bin/env ruby

require 'irb'
require 'irb/completion'

module IRB
  def IRB.parse_opts
    # Don't touch ARGV, which belongs to the app which called this module.
  end

  def IRB.start_session(*args)
    unless $irb
      IRB.setup nil
      ## maybe set some opts here, as in parse_opts in irb/init.rb?
    end

    workspace = WorkSpace.new(*args)

    @CONF[:PROMPT_MODE] = :SIMPLE

    # Enables _ as last value
    @CONF[:EVAL_HISTORY] = 1000
    @CONF[:SAVE_HISTORY] = 100

    if @CONF[:SCRIPT] ## normally, set by parse_opts
      $irb = Irb.new(workspace, @CONF[:SCRIPT])
    else
      $irb = Irb.new(workspace)
    end

    @CONF[:IRB_RC].call($irb.context) if @CONF[:IRB_RC]
    @CONF[:MAIN_CONTEXT] = $irb.context

    trap 'INT' do
      $irb.signal_handle
    end

    custom_configuration if defined?(IRB.custom_configuration)

    begin
      catch :IRB_EXIT do
        $irb.eval_input
      end
    ensure
      IRB.irb_at_exit
    end

    ## might want to reset your app's interrupt handler here
  end
end

class Object
  include IRB::ExtendCommandBundle # so that Marshal.dump works
end

if __FILE__ == $0
  x = Object.new
  puts "Started irb shell for x with current binding"
  IRB.start_session(binding, x)
end
