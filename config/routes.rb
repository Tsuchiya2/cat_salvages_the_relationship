Rails.application.routes.draw do
  root 'customers#top'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
