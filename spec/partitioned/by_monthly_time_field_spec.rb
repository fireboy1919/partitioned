require 'spec_helper'
require "#{File.dirname(__FILE__)}/../support/tables_spec_helper"
require "#{File.dirname(__FILE__)}/../support/shared_example_spec_helper_for_time_key"

module Partitioned

  describe ByMonthlyTimeField do

    include TablesSpecHelper

    module MonthlyTimeField
      class Employee < Partitioned::ByMonthlyTimeField
        belongs_to :company, :class_name => 'Company'

        def self.partition_time_field
          return :created_at
        end

        partitioned do |partition|
          partition.index :id, :unique => true
          partition.foreign_key :company_id
        end
      end # Employee
    end # MonthlyTimeField

    before(:all) do
      @employee = MonthlyTimeField::Employee
      create_tables
      dates = @employee.partition_generate_range(DATE_NOW,
                                                 DATE_NOW + 1.month)
      @employee.create_new_partition_tables(dates)
      ActiveRecord::Base.connection.execute <<-SQL
        insert into employees_partitions.
          p#{DATE_NOW.at_beginning_of_month.strftime('%Y%m')}
          (company_id,name) values (1,'Keith');
      SQL
    end

    after(:all) do
      drop_tables
    end

    let(:class_by_monthly_time_field) { ::Partitioned::ByMonthlyTimeField }

    describe "model is abstract class" do

      it "returns true" do
        class_by_monthly_time_field.abstract_class.should be_true
      end

    end # model is abstract class

    describe "#partition_normalize_key_value" do

      it "returns date with day set to 1st of the month" do
        class_by_monthly_time_field.
            partition_normalize_key_value(Date.parse('2011-01-05')).
            should == Date.parse('2011-01-01')
      end

    end # #partition_normalize_key_value

    describe "#partition_table_size" do

      it "returns 1.month" do
        class_by_monthly_time_field.partition_table_size.should == 1.month
      end

    end # #partition_table_size

    describe "partitioned block" do

      let(:data) do
        class_by_monthly_time_field.configurator_dsl.data
      end

      context "checks data in the base_name is Proc" do

        it "returns Proc" do
          data.base_name.should be_is_a Proc
        end

      end # checks data in the on_field is Proc

      context "checks data in the base_name" do

        it "returns base_name" do
          data.base_name.call(@employee, Date.parse('2011-02-05')).should == "201102"
        end

      end # checks data in the base_name

    end # partitioned block

    it_should_behave_like "check that basic operations with postgres works correctly for time key", MonthlyTimeField::Employee

  end # ByMonthlyTimeField

end # Partitioned
