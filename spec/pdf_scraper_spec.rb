require_relative '../pdf_scraper'
require 'open-uri'

describe PdfScraper do
  it "can download the PDF file" do
    VCR.turned_off do
      WebMock.allow_net_connect!
      Net::HTTP.start(PdfScraper::PDF_HOST, 80) {|http| expect(http.head(PdfScraper::PDF_PATH).code).to eq "200" }
    end
  end

  describe "#scrape", :vcr do
    it "scrapes MPs details correctly" do
      records = subject.scrape
      expect(records["Curtin"]).to eq 'Julie.Bishop.MP@aph.gov.au'
      expect(records["Durack"]).to eq 'Melissa.Price.MP@aph.gov.au'
    end

    #TODO this gets everything except tony abbott and clive palmer
    it "scrapes the right number of MPs" do
      records = subject.scrape
      expect(records.size).to eq 149
    end
  end
end
