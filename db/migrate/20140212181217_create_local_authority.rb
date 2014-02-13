class CreateLocalAuthority < ActiveRecord::Migration
  def change
    create_table :local_authorities do |t|
      t.string :name
      t.references :court

      t.timestamps
    end
  end
end
