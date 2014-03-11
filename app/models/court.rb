class Court < ActiveRecord::Base
  attr_accessor :active_area_of_law
  belongs_to :area
  has_many :addresses
  has_many :opening_times
  has_many :contacts
  has_many :emails
  has_many :court_facilities
  has_many :court_types_courts
  has_many :court_types, through: :court_types_courts
  has_many :courts_areas_of_law
  has_many :areas_of_law, through: :courts_areas_of_law
  has_many :postcode_courts, dependent: :destroy

  has_many :court_council_links
  has_many :councils, through: :court_council_links

  attr_accessible :court_number, :info, :name, :slug, :area_id, :cci_code, :old_id,
                  :old_court_type_id, :area, :addresses_attributes, :latitude, :longitude, :court_type_ids,
                  :area_of_law_ids, :opening_times_attributes, :contacts_attributes, :emails_attributes,
                  :court_facilities_attributes, :image, :image_file, :remove_image_file, :display, :alert,
                  :info_leaflet, :defence_leaflet, :prosecution_leaflet, :juror_leaflet,
                  :postcode_list, :children_councils_list, :divorce_councils_list, :adoption_councils_list

  accepts_nested_attributes_for :addresses, allow_destroy: true
  accepts_nested_attributes_for :opening_times, allow_destroy: true
  accepts_nested_attributes_for :contacts, allow_destroy: true
  accepts_nested_attributes_for :emails, allow_destroy: true
  accepts_nested_attributes_for :court_facilities, allow_destroy: true

  validates :name, presence: true
  validates :latitude, numericality: { greater_than:  -90, less_than:  90 }, presence: true, if: :has_visiting_address?
  validates :longitude, numericality: { greater_than: -180, less_than: 180 }, presence: true, if: :has_visiting_address?

  validate :check_postcode_errors

  has_paper_trail :ignore => [:created_at, :updated_at]

  extend FriendlyId
  friendly_id :name, use: [:slugged, :history]

  geocoded_by :latitude => :lat, :longitude => :lng

  mount_uploader :image_file, CourtImagesUploader

  acts_as_gmappable :process_geocoding => lambda { |obj| obj.addresses.first.address_line_1.present? },
                    :validation => false,
                    :process_geocoding => false

  def gmaps4rails_address
  #describe how to retrieve the address from your model, if you use directly a db column, you can dry your code, see wiki
    "#{self.addresses.first.address_line_1}, #{self.addresses.first.town.name}, #{self.addresses.first.town.county.name}"
  end

  # Scope methods
  scope :visible,         -> { where(display: true) }
  scope :by_name,         -> { order('LOWER(courts.name)') }
  scope :by_area_of_law,  -> (area_of_law) { joins(:areas_of_law).where(areas_of_law: {name: area_of_law}) if area_of_law.present? }
  scope :search,          -> (q) { where('courts.name ilike ?', "%#{q.downcase}%") if q.present? }
  scope :for_council,     -> (council) {joins(:councils).where("councils.name" => council) }
  
  def self.by_postcode_court_mapping(postcode, area_of_law = nil)
    if postcode.present?
      if postcode_court = PostcodeCourt.where("court_id IS NOT NULL AND ? like lower(postcode) || '%'",
            postcode.gsub(/\s+/, "").downcase)
            .order('-length(postcode)').first
        #Using a reverse id lookup instead of just postcode_court.court as a workaround for the distance calculator
        if area_of_law
          by_area_of_law(area_of_law).where(id: postcode_court.court_id).limit(1)
        else
          where(id: postcode_court.court_id).limit(1)
        end
      else
        []
      end
    else
      self
    end
  end

  def self.search(q)
    where('courts.name ilike ?', "%#{q.downcase}%") if q.present?
  end

  def self.for_council(council, area_of_law)
    joins(:court_council_links).joins(:councils).where("councils.name" => council, "court_council_links.area_of_law_id" => "#{area_of_law.id}")
  end

  def locatable?
    longitude && latitude && !addresses.visiting.empty?
  end

  def fetch_image_file
    if image.present?
      self.image_file.download!("https://hmctscourtfinder.justice.gov.uk/courtfinder/images/courts/#{self.image.to_s}")
      self.image_file.store!
    end
  end

  def leaflets
    @leaflets || begin
      @leaflets = []
      if self.court_types.empty? || self.court_types.pluck(:name).any? {|ct| ct != "Family Proceedings Court" && ct != "County Court" && ct != "Tribunal"}
        @leaflets.push("defence", "prosecution")
      end
      if self.court_types.pluck(:name).any? {|ct| ct == "Crown Court"}
        @leaflets << "juror"
      end
      @leaflets
    end
  end

  def is_county_court?
    # 31 is the ID of county court
    court_types.pluck(:id).include? 31
  end

  def area_councils_list(area_of_law = nil)
    relation = area_councils(area_of_law)
    relation.map(&:name).join(',')
  end

  def area_councils(area_of_law)
    area_of_law_id = AreaOfLaw.where(name: area_of_law).first.id

    relation = court_council_links.by_name
    relation = relation.where(area_of_law_id: area_of_law_id)
    relation.map(&:council)
  end

  def set_area_councils_list(list, area_of_law = nil)
    area_of_law_id = AreaOfLaw.where(name: area_of_law).first.id
    names = list.split(',').compact

    # map existing councils
    exisiting_council_ids = court_council_links.where(area_of_law_id: area_of_law_id).map(&:council_id)
    new_council_ids = names.map{|name| Council.where(name: name).first.id }.compact
    
    # delete old records removed from list 
    exisiting_council_ids.each do |id|
      court_council_links.where(council_id: id, area_of_law_id: area_of_law_id).first.delete unless new_council_ids.include?(id)
    end

    # add new records included in list
    new_council_ids.each do |id|
      court_council_links.create!(council_id: id, area_of_law_id: area_of_law_id) unless exisiting_council_ids.include?(id)
    end
  end

  def children_councils
    self.area_councils 'Children'
  end

  def children_councils_list
    self.area_councils_list 'Children'
  end

  def children_councils_list=(list)
    self.set_area_councils_list list, 'Children'
  end

  def divorce_councils
    self.area_councils 'Divorce'
  end
  
  def divorce_councils_list
    self.area_councils_list 'Divorce'
  end

  def divorce_councils_list=(list)
    self.set_area_councils_list list, 'Divorce'
  end

  def adoption_councils
    self.area_councils 'Adoption'
  end

  def adoption_councils_list
    self.area_councils_list 'Adoption'
  end

  def adoption_councils_list=(list)
    self.set_area_councils_list list, 'Adoption'
  end

  def postcode_list
    postcode_courts.map(&:postcode).sort.join(", ")
  end

  def postcode_list=(postcodes)
    new_postcode_courts = []
    @postcode_errors = []
    postcodes.split(",").map do |postcode|
      postcode = postcode.gsub(/[^0-9a-z ]/i, "").downcase
      if pc = existing_postcode_court(postcode)
        if pc.court && pc.court == self
          new_postcode_courts << pc
        elsif pc.court && pc.court != self
          @postcode_errors << "Post code \"#{postcode}\" is already assigned to #{pc.court.name}. Please remove it from this court before assigning it to #{self.name}."
        end
      else
        new_postcode_courts << PostcodeCourt.new(postcode: postcode)
      end
    end
    self.postcode_courts = new_postcode_courts
  end

  def existing_postcode_court(postcode)
    PostcodeCourt.where("lower(postcode) = ?", postcode).first
  end

  def check_postcode_errors
    @postcode_errors.each {|e| errors.add(:postcode_courts, e) } if @postcode_errors
  end

  # def method_missing(method_sym, *arguments, &block)
  #   # the first argument is a Symbol, so you need to_s it if you want to pattern match
  #   if matched = method_sym.to_s.match(/^([a-z]+)_councils_list=?$/)
  #     return super unless area_of_law = AreaOfLaw.where('LOWER(name) = ?',matched[1].downcase).first
  #     if method_sym.to_s[-1] == '='
  #       send("councils_list=", [arguments.first, area_of_law])
  #     else
  #       send("councils_list", [area_of_law])
  #     end
  #   else
  #     super
  #   end
  # end

  protected

    def has_visiting_address?
      addresses.visiting.count > 0
    end
end
