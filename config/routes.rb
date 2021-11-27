Rails.application.routes.draw do
  root 'customers#top'
  get 'terms',              to: 'customers#terms'
  get 'privacy_policy',     to: 'customers#privacy_policy'
  resources :feedbacks,     only: %i[new create]
  namespace :operator do
    get    'cat_in',        to: 'operator_sessions#new'
    post   'cat_in',        to: 'operator_sessions#create'
    delete 'cat_out',       to: 'operator_sessions#destroy'
    resources :operates,    only: %i[index]
    resources :contents
    resources :alarm_contents
    resources :feedbacks,   only: %i[index show destroy]
    resources :line_groups, only: %i[index show edit update destroy]
    post Rails.application.credentials.callback_route, to: 'webhooks#callback'
  end
  mount LetterOpenerWeb::Engine, at: '/letter_opener' if Rails.env.development?
end
