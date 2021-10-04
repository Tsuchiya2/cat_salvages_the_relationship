Rails.application.routes.draw do
  root 'customers#top'
  get '/usage', to: 'customers#usage'
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
