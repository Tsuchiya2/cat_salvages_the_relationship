namespace :call_notice do
  desc '短いスパンでの働きかけを行う'
  task call_reminds: :environment do
    Scheduler.call_notice
  end
end
