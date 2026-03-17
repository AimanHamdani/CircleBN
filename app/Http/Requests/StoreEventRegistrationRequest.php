<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

class StoreEventRegistrationRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'gender' => ['required', 'string', 'in:male,female,other'],
            'age' => ['required', 'integer', 'min:1', 'max:120'],
            'emergency_contact' => ['required', 'string', 'max:255'],
            'tshirt_size' => ['nullable', 'string', 'in:XS,S,M,L,XL,XXL'],
        ];
    }

    /**
     * @return array<string, string>
     */
    public function messages(): array
    {
        return [
            'gender.required' => 'Please select your gender.',
            'age.required' => 'Please enter your age.',
            'emergency_contact.required' => 'An emergency contact number is required.',
        ];
    }
}
