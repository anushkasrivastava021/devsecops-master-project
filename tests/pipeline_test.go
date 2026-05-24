package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformPipelinePlan(t *testing.T) {
	t.Parallel()

	// Define the configuration for Terratest
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Tell Terratest exactly where to find our infrastructure code
		TerraformDir: "../terraform",
	})

	// Run 'terraform init' and 'terraform plan'
	// This will fail the test if the Terraform code has syntax errors or AWS rejects it
	planStruct := terraform.InitAndPlan(t, terraformOptions)

	// Assert that a plan was successfully generated (it should not be nil)
	assert.NotNil(t, planStruct)
}