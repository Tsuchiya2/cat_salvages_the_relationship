Rails.application.routes.draw do
  root 'customers#top'
  get 'usage', to: 'customers#usage'
  namespace :operator do
    get    'cat_in',  to: 'operator_sessions#new'
    post   'cat_in',  to: 'operator_sessions#create'
    delete 'cat_out', to: 'operator_sessions#destroy'
    resources :boards, only: %i[index]
    resources :contents
    resources :alarm_contents
    post Rails.application.credentials.callback_route, to: 'catch_events#callback'
  end
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
