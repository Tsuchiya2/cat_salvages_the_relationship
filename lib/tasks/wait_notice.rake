namespace :wait_notice do
  desc '不定期な働きかけを行う'
  task wait_reminds: :environment do
    Scheduler.wait_notice
  end
end
