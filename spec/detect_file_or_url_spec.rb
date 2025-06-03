
require 'rouge'
require 're/detect_file_or_url'

RSpec.describe 'detect_file_or_url' do

  it 'does not detect a plain word outside of brackets' do
    res =
    expect(detect_file_or_url(' * (C) @HC Cancel Sussex Inn.', 15)).to be_nil
  end
end
