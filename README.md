<div align="center">

# 🐱 ReLINE - Cat Messenger Bot

[![Ruby](https://img.shields.io/badge/Ruby-3.4.6-CC342D?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/Rails-8.1.1-CC0000?style=flat&logo=ruby-on-rails&logoColor=white)](https://rubyonrails.org/)
[![LINE](https://img.shields.io/badge/LINE-Messaging_API-00C300?style=flat&logo=line&logoColor=white)](https://developers.line.biz/en/services/messaging-api/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Keep your LINE groups alive with our friendly cat companion!**

[🌐 Visit Website](https://www.cat-reline.com/) | [📖 Documentation](https://qiita.com/Tsuchiy_2/items/4e8c038f58c23b57b0be) | [🚀 Getting Started](#-getting-started)

![Cat Mascot](/readme-images/cat.jpg)

</div>

---

## 📖 Overview

**ReLINE** is an intelligent LINE bot service that revitalizes dormant group chats by sending engaging messages from our friendly cat mascot. When a LINE group becomes inactive for a certain period, the bot automatically sends conversation starters to re-engage members and restore community interaction.

### 🎯 Key Features

- 🤖 **Automated Group Monitoring** - Tracks group activity and detects dormancy
- 💬 **Smart Message Delivery** - Sends contextual conversation starters at optimal times
- 📊 **Admin Dashboard** - Manage groups and monitor engagement metrics
- 🔐 **Secure Authentication** - Protected admin access with role-based permissions
- 📈 **Analytics & Insights** - Track conversation revival success rates

---

## 🎬 How It Works

![Usage Example](/readme-images/example.jpg)

<div align="center">

### User Interface Gallery

</div>

| Web Landing Page | QR Code Screen | LINE App Integration |
|:---:|:---:|:---:|
| ![Web Top Page](/readme-images/web-top-page.jpg) | ![QR Code](/readme-images/qr-code.jpg) | ![LINE Page](/readme-images/line-page.jpg) |
| Main landing page with mascot and "Add Friend" button | QR code display for desktop users | Mobile app integration view |

---

## 🛠 Tech Stack

### Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| ![Ruby](https://img.shields.io/badge/Ruby-3.4.6-CC342D?style=flat&logo=ruby&logoColor=white) | 3.4.6 | Core language |
| ![Rails](https://img.shields.io/badge/Rails-8.1.1-CC0000?style=flat&logo=ruby-on-rails&logoColor=white) | 8.1.1 | Web framework |
| ![MySQL](https://img.shields.io/badge/MySQL-5.7-4479A1?style=flat&logo=mysql&logoColor=white) | 0.5.x | Development database |
| ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-blue?style=flat&logo=postgresql&logoColor=white) | Latest | Production database |
| ![LINE](https://img.shields.io/badge/LINE_Bot_API-2.0-00C300?style=flat&logo=line&logoColor=white) | 2.0 | Messaging integration |

#### Core Gems

- **Authentication** - `sorcery` - Secure admin login system
- **Authorization** - `pundit` - Policy-based access control
- **Messaging** - `line-bot-api` - LINE Messaging API integration
- **Monitoring** - `prometheus-client` - Metrics collection and monitoring
- **Logging** - `lograge` - Structured logging for production

#### Development & Testing

- **Testing Framework** - `rspec-rails` - Comprehensive test suite
- **Code Quality** - `rubocop` with Rails, Performance, and RSpec extensions
- **Test Data** - `factory_bot_rails`, `faker` - Factory and fixture generation
- **Security** - `brakeman`, `bundler-audit` - Security vulnerability scanning
- **Coverage** - `simplecov` - Test coverage analysis

### Frontend

| Technology | Purpose |
|------------|---------|
| ![Bootstrap](https://img.shields.io/badge/Bootstrap-5.1.3-7952B3?style=flat&logo=bootstrap&logoColor=white) | Responsive UI framework |
| ![JavaScript](https://img.shields.io/badge/JavaScript-ES6+-F7DF1E?style=flat&logo=javascript&logoColor=black) | Client-side interactivity |
| ![Stimulus](https://img.shields.io/badge/Stimulus-Hotwire-FF6600?style=flat) | JavaScript framework |
| ![Turbo](https://img.shields.io/badge/Turbo-Hotwire-FF6600?style=flat) | SPA-like navigation |

#### Asset Pipeline

- **JS Bundling** - `jsbundling-rails` with esbuild
- **CSS Bundling** - `cssbundling-rails` with Bootstrap
- **Asset Serving** - `propshaft` - Modern asset pipeline

---

## 📐 Architecture

### Database Schema

![ER Diagram](/readme-images/reline-er.jpg)

### Infrastructure

![Infrastructure Diagram](/readme-images/reline-infra.jpg)

### Event Processing Architecture

![LINE Bot Reaction Flow](/readme-images/line-bot-reaction.jpg)

Our event processing system elegantly handles multiple LINE Messaging API events through a single endpoint, utilizing:

- **Service Objects** - Dedicated service classes for each event type
- **Strategy Pattern** - Dynamic event handler selection
- **Dry Controllers** - Minimal controller logic with delegated responsibilities
- **Rubocop Compliant** - Adheres to strict style guidelines without sacrificing readability

---

## 📊 Test Coverage

![Test Coverage](/readme-images/coverage.jpg)

- **Model Specs** - Comprehensive unit tests for business logic
- **System Specs** - End-to-end integration testing
- **RSpec** - Primary testing framework
- **SimpleCov** - Coverage reporting

---

## 🚀 Getting Started

### Prerequisites

- Ruby 3.4.6
- Rails 8.1.1
- MySQL 5.7+ (development) or PostgreSQL (production)
- LINE Developer Account ([Create one here](https://developers.line.biz/))

### Installation

1. **Clone the repository**

```bash
git clone https://github.com/yourusername/cat_salvages_the_relationship.git
cd cat_salvages_the_relationship
```

2. **Install dependencies**

```bash
bundle install
npm install
```

3. **Configure environment variables**

Create a `config/credentials.yml.enc` file or set environment variables:

```bash
# LINE Messaging API
LINE_CHANNEL_SECRET=your_channel_secret
LINE_CHANNEL_TOKEN=your_channel_token

# Database (development uses MySQL by default)
DATABASE_URL=mysql2://username:password@localhost/reline_development
```

> ⚠️ **Note**: The `master.key` file is managed by the development team. For personal testing, generate a new key or use environment variables.

4. **Setup database**

```bash
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

5. **Build assets**

```bash
npm run build
npm run build:css
```

6. **Start the server**

```bash
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000) to see the application.

### Available Commands

```bash
# Run tests
bin/rails spec

# Check code quality
bundle exec rubocop

# Security audit
bundle exec brakeman
bundle exec bundler-audit

# View routes
bin/rails routes

# Rails console
bin/rails console
```

---

## 🎓 Technical Highlights

### Challenge: Event-Driven Architecture

One of the most significant challenges was implementing a clean event-driven architecture for the LINE Messaging API. A single webhook endpoint receives multiple event types (messages, follows, joins, leaves, etc.), each requiring different processing logic.

**Solution:**

We implemented a service-oriented architecture that:
- Separates event handling logic into dedicated service objects
- Maintains thin controllers that delegate to services
- Uses polymorphic event processors for extensibility
- Adheres to SOLID principles and Rubocop standards

This architecture evolved through:
- Feedback from experienced engineers
- Study of "Perfect Ruby on Rails" best practices
- Iterative refactoring to avoid Fat Models and Fat Controllers
- Rigorous Rubocop compliance

---

## 📚 Resources

### Blog Posts

- 📝 [Building a LINE Bot with Rails - A Beginner's Guide](https://qiita.com/Tsuchiy_2/items/4e8c038f58c23b57b0be) (Japanese)

### Documentation

- [LINE Messaging API Documentation](https://developers.line.biz/en/docs/messaging-api/)
- [Rails 8.1 Guides](https://guides.rubyonrails.org/)
- [Ruby 3.4 Documentation](https://docs.ruby-lang.org/en/3.4.0/)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👤 Author

**Tsuchiya Yuji**

- GitHub: [@Tsuchiya2](https://github.com/Tsuchiya2)
- Qiita: [@Tsuchiy_2](https://qiita.com/Tsuchiy_2)

---

<div align="center">

**Made with ❤️ and Ruby**

⭐ Star this repository if you find it helpful!

</div>
