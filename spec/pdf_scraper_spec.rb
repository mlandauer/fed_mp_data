require_relative '../pdf_scraper'
require 'open-uri'

describe PdfScraper do
  it "can download the PDF file" do
    VCR.turned_off do
      WebMock.allow_net_connect!
      Net::HTTP.start(PdfScraper::PDF_HOST, 80) {|http| expect(http.head(PdfScraper::MP_URL).code).to eq "200" }
      Net::HTTP.start(PdfScraper::PDF_HOST, 80) {|http| expect(http.head(PdfScraper::SENATOR_URL).code).to eq "200" }
    end
  end

  describe "#scrape_pdf", :vcr do
    it "scrapes MP details correctly" do
      records = subject.scrape_pdf(PdfScraper::MP_URL, :representatives)
      expect(records["(02) 6277 7500"]).to eq({"email"=>"Julie.Bishop.MP@aph.gov.au", "electorate_tel"=>"(02) 6277 7500", "electorate"=>"Curtin", "surname"=>"Bishop", "type"=>"mp"})
      expect(records["(02) 6277 4242"]).to eq({"email"=>"Melissa.Price.MP@aph.gov.au", "electorate_tel"=>"(02) 6277 4242", "electorate"=>"Durack", "surname"=>"Price", "type"=>"mp"})

      expect(records.count).to eq 148
    end

    it "scrapes senator details corectly" do
      records = subject.scrape_pdf(PdfScraper::SENATOR_URL, :senate)
      expect(records["(03) 6224 3707"]).to eq({"electorate_tel"=>"(03) 6224 3707", "state"=>"TAS", "surname"=>"Abetz", "email"=>"senator.abetz@aph.gov.au", "type"=>"senator"})
      expect(records.count).to eq 75
    end
  end

  describe "#new_senator_line?" do
    specify { expect(subject.send(:new_senator_line?, "4      Bilyk, Senator CatrynaLouise                  TAS        ALP      Suite 3, Kingston Plaza, 20 Channel Highway,      (03) 6229 4444 ")).to be_truthy }
    specify { expect(subject.send(:new_senator_line?, "**34   Lindgren, Senator JoannaMaria                 QLD         LP       2166 Logan Road, Upper Mount Gravatt QLD 4122    (07) 3422 1990 ")).to be_truthy }
    specify { expect(subject.send(:new_senator_line?, " 44 Parliament                                                                                                             as at 21 May 2015 ")).to be_falsey }
    specify { expect(subject.send(:new_senator_line?, "3    Chosen by the Australian Capital Territory Legislative Assemblya casual vacancy(vice K. Lundy), pursuant to section 15 of the Constitution.  ")).to be_falsey }
  end

  describe "#read_senator_state_and_surname" do
    it "should senator read state and surname" do
      line = '2      Back, Senator Christopher John (Chris)        WA          LP      Unit E5, 817 Beeliar Drive,                       (08) 9414 7288'
      expect(subject.send(:read_senator_state_and_surname, line)).to eq ['WA', 'Back']
    end

    it "should read senators with title 'the hon'" do
      line = '1      Abetz, Senator the Hon Eric                   TAS         LP      Highbury House, 136 Davey Street,                 (03) 6224 3707'
      expect(subject.send(:read_senator_state_and_surname, line)).to eq ['TAS', 'Abetz']
    end

    it "should handle extra long name columns" do
      line = '24     Fifield, Senator the Hon Mitchell Peter (Mitch) VIC         LP      42 Florence Street, Mentone VIC 3194               (03) 9584 2455'
      expect(subject.send(:read_senator_state_and_surname, line)).to eq ['VIC', 'Fifield']
    end

    it "should handle state starting in a different column" do
      line = '73     Williams, Senator John Reginald              NSW        NATS      144 Byron Street, Inverell NSW 2360              (02) 6721 4500'
      expect(subject.send(:read_senator_state_and_surname, line)).to eq ['NSW', 'Williams']
    end
  end

  describe "#read_mp_details" do
    it "should read the MP's details" do
      lines = ['Abbott, The Hon Anthony John         Warringah,         LP         Level 2, 17 Sydney Road (PO Box 450), Manly                 Tel: (02) 6277 7700']
      expect(subject.send(:read_mp_details, lines)).to eq ['(02) 6277 7700', 'Abbott', 'Warringah']
    end

    it "should read the MP's details even when the order is backwards" do
      lines = ['                                       McMillan,           LP        46C Albert Street, Warragul Vic 3820                           Tel: (02) 6277 4233',
                'Broadbent, Mr Russell Evan']
      expect(subject.send(:read_mp_details, lines)).to eq ['(02) 6277 4233', 'Broadbent', 'McMillan']
    end

    it "should read MP's details when their first name starts a new line" do
      lines = [ 'van Manen, Mr Albertus                 Forde,              LP        Tenancy 4/96 George Street (PO Box 884), Beenleigh             Tel: (02) 6277 4719',
              '                                       Qld                           Qld 4207                                                       Fax: (02) 6277 8553',
              'Johannes (Bert)',
              '                                                                     Tel : (07) 3807 6340, Fax : (07) 3807 1990',
              '                                                                     E-mail: bert.vanmanen.mp@aph.gov.au']
      expect(subject.send(:read_mp_details, lines)).to eq ['(02) 6277 4719', 'van Manen', 'Forde']
    end
  end

  describe "#read_email" do
    context "senators" do
      it "should read emails" do
        line = '         Minister Assisting the Prime Ministerfor the                    Email: senator.abetz@aph.gov.au'
        expect(subject.send(:read_email, 'Email:', PdfScraper::SENATOR_EMAIL_START_COL, line)).to eq 'senator.abetz@aph.gov.au'
      end
  
      it "should not include any trailing crap" do
        line = '                                                                         Email: senator.bushby@aph.gov.au                  (03) 6244 8521 (fax)'
        expect(subject.send(:read_email, 'Email:', PdfScraper::SENATOR_EMAIL_START_COL, line)).to eq 'senator.bushby@aph.gov.au'
      end
    end

    context "mps" do
      it "should read emails" do
        line = '                                                                   E-mail: A.Albanese.MP@aph.gov.au'
        expect(subject.send(:read_email, 'E-mail:', PdfScraper::MP_EMAIL_START_COL, line)).to eq 'A.Albanese.MP@aph.gov.au'
      end
    end
  end
end
