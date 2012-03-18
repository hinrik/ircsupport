# https://github.com/rubinius/rubinius/issues/1575
if RUBY_ENGINE != "rbx"
  require 'simplecov'

  SimpleCov.start do
    add_filter "/test/"
  end
end
